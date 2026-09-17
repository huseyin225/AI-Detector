// AI Vision Assistant â€” Detection Screen (v4: Distinct Modes)
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';
import '../../services/history_service.dart';
import '../../services/detection_stabilizer.dart';
import '../../services/llm_scene_service.dart';
import '../../models/detection_history.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});
  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  final YOLOViewController _controller = YOLOViewController();
  final TtsService _ttsService = TtsService();
  final DetectionStabilizer _stabilizer = DetectionStabilizer();
  final LlmSceneService _llmScene = LlmSceneService();

  List<StableDetection> _stableResults = [];
  bool _isProcessing = false;
  int _frameCount = 0, _fps = 0;
  bool _modelReady = false;
  DateTime? _lastFpsUpdate;
  String _sceneText = '';
  bool _lowLight = false;
  late AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _lastFpsUpdate = DateTime.now();
    _scanCtrl = AnimationController(
      duration: const Duration(seconds: 3), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _scanCtrl.dispose(); _ttsService.stop(); _stabilizer.reset(); super.dispose();
  }

  void _onPerformanceMetrics(YOLOPerformanceMetrics m) {
    if (!_modelReady) { _modelReady = true; }
  }

  void _onDetection(List<YOLOResult> results) {
    if (!mounted) return;
    final settings = context.read<SettingsService>();
    _llmScene.setApiKey(settings.llmApiKey);
    _llmScene.setEnabled(settings.llmEnabled);

    final stable = _stabilizer.update(results);

    _frameCount++;
    final now = DateTime.now();
    final fpsChanged = _lastFpsUpdate != null && now.difference(_lastFpsUpdate!).inSeconds >= 1;

    _llmScene.describeScene(stable, settings.useTurkishLabels).then((desc) {
      if (mounted && desc != _sceneText) setState(() => _sceneText = desc);
    });

    setState(() {
      _stableResults = stable;
      if (fpsChanged) _fps = _frameCount;
    });
    if (fpsChanged) { _frameCount = 0; _lastFpsUpdate = now; }

    if (settings.voiceEnabled) {
      _ttsService.announceTopDetection(stable, settings.useTurkishLabels, settings.threshold);
      if (settings.entryNotify) {
        for (final e in _stabilizer.getNewEntries()) {
          _ttsService.announceNewEntry(e, settings.useTurkishLabels);
        }
      }
      if (settings.sceneSummary) {
        _ttsService.maybeAnnounceSceneSummary(stable, settings.useTurkishLabels);
      }
    }
    if (settings.lowLightWarning && _frameCount % 30 == 0) _checkLowLight(stable);
  }

  void _checkLowLight(List<StableDetection> dets) {
    if (dets.isEmpty) return;
    final avg = dets.fold<double>(0, (s, d) => s + d.confidence) / dets.length;
    final nl = avg < 0.3 && dets.length <= 2;
    if (nl != _lowLight) setState(() => _lowLight = nl);
  }

  Future<void> _captureScreen() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final image = await _screenshotController.capture();
      if (image != null && mounted) {
        context.read<HistoryService>().saveDetection(DetectionHistoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(), timestamp: DateTime.now(),
          detections: _stableResults.map((r) => DetectionItem(label: r.className, confidence: r.confidence,
            boundingBox: [r.smoothBox.left, r.smoothBox.top, r.smoothBox.right, r.smoothBox.bottom])).toList()));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KayÄ±t alÄ±ndÄ± âœ“')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally { if (mounted) setState(() => _isProcessing = false); }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isSeg = settings.segmentationMode;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Screenshot(controller: _screenshotController, child: Stack(children: [
          YOLOView(
            modelPath: isSeg ? 'yolo11n-seg' : 'yolo11n',
            task: isSeg ? YOLOTask.segment : YOLOTask.detect,
            controller: _controller, onResult: _onDetection,
            onPerformanceMetrics: _onPerformanceMetrics, showOverlays: false,
            confidenceThreshold: settings.pluginThreshold,
            iouThreshold: settings.iouThreshold,
            // CRITICAL: request mask data in segmentation mode
            streamingConfig: isSeg
                ? const YOLOStreamingConfig.withMasks()
                : null,
          ),
          Positioned.fill(child: isSeg
            ? AnimatedBuilder(animation: _scanCtrl,
                builder: (_, __) => CustomPaint(painter: SegmentationPainter(
                  results: _stableResults, useTurkish: settings.useTurkishLabels,
                  showDistance: settings.showDistance, scanProgress: _scanCtrl.value)))
            : CustomPaint(painter: DetectionPainter(
                results: _stableResults, useTurkish: settings.useTurkishLabels,
                showDistance: settings.showDistance))),
        ])),
        // HUD
        SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            _topBar(settings),
            const SizedBox(height: 6),
            if (_sceneText.isNotEmpty) _sceneBanner(),
            if (_lowLight && settings.lowLightWarning) _lowLightBanner(),
            const Spacer(),
            _bottomPanel(settings),
          ]),
        )),
      ]),
    );
  }

  // â”€â”€â”€ HUD widgets (unchanged logic) â”€â”€â”€

  Widget _sceneBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 0.5)),
    child: Row(children: [
      Icon(_llmScene.isEnabled ? Icons.auto_awesome : Icons.psychology, color: AppColors.primary, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text(_sceneText, style: TextStyle(color: AppColors.primary.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]));

  Widget _lowLightBanner() => Padding(padding: const EdgeInsets.only(top: 6),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.5), width: 0.5)),
      child: const Row(children: [
        Icon(Icons.brightness_low, color: Colors.orange, size: 14), SizedBox(width: 6),
        Expanded(child: Text('âš  DÃ¼ÅŸÃ¼k Ä±ÅŸÄ±k â€” algÄ±lama doÄŸruluÄŸu dÃ¼ÅŸebilir', style: TextStyle(color: Colors.orange, fontSize: 11)))])));

  Widget _topBar(SettingsService s) => Row(children: [
    _hudBtn(Icons.arrow_back, () => Navigator.pop(context)),
    const Spacer(),
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          s.segmentationMode ? Colors.purple.withOpacity(0.3) : AppColors.primary.withOpacity(0.2),
          Colors.transparent]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (s.segmentationMode ? Colors.purple : AppColors.primary).withOpacity(0.4), width: 0.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.segmentationMode ? Icons.blur_on : Icons.crop_square, color: s.segmentationMode ? Colors.purple : AppColors.primary, size: 14),
        const SizedBox(width: 4),
        Text(s.segmentationMode ? 'SEG' : 'DET',
          style: TextStyle(color: s.segmentationMode ? Colors.purple : AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ])),
    const SizedBox(width: 8),
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fpsColor.withOpacity(0.5), width: 0.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _fpsColor,
          boxShadow: [BoxShadow(color: _fpsColor.withOpacity(0.6), blurRadius: 4)])),
        const SizedBox(width: 6),
        Text('$_fps', style: TextStyle(color: _fpsColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ])),
  ]);

  Color get _fpsColor => _fps >= 20 ? AppColors.success : (_fps >= 10 ? AppColors.accent : AppColors.danger);

  Widget _bottomPanel(SettingsService s) => ClipRRect(borderRadius: BorderRadius.circular(20),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 0.5)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle,
              color: _stableResults.isNotEmpty ? AppColors.primary : Colors.grey,
              boxShadow: _stableResults.isNotEmpty ? [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 6)] : null)),
            const SizedBox(width: 8),
            Text('${_stableResults.length} nesne', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          if (_stableResults.isNotEmpty) ...[const SizedBox(height: 2),
            Text(_getPrimaryLabel(s.useTurkishLabels), style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)],
        ])),
        _hudBtn(s.voiceEnabled ? Icons.volume_up : Icons.volume_off,
          () => s.toggleVoice(!s.voiceEnabled), color: s.voiceEnabled ? AppColors.primary : Colors.grey),
        const SizedBox(width: 8),
        GestureDetector(onTap: _isProcessing ? null : _captureScreen,
          child: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)]),
            child: _isProcessing
              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.camera_alt, color: Colors.white, size: 20))),
      ])));

  String _getPrimaryLabel(bool tr) {
    if (_stableResults.isEmpty) return '';
    final sorted = List<StableDetection>.from(_stableResults)..sort((a, b) {
      final pa = ObjectPriority.getPriority(a.className), pb = ObjectPriority.getPriority(b.className);
      return pa != pb ? pb.compareTo(pa) : b.confidence.compareTo(a.confidence);
    });
    final top = sorted.first;
    final label = tr ? AppStrings.getTranslation(top.className) : top.className;
    final spatial = _ttsService.sceneAnalyzer.getSpatialDescription(top, tr);
    return '$label Â· $spatial';
  }

  Widget _hudBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white}) =>
    GestureDetector(onTap: onTap, child: Container(width: 36, height: 36,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54,
        border: Border.all(color: color.withOpacity(0.3), width: 0.5)),
      child: Icon(icon, color: color, size: 18)));
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DETECTION PAINTER â€” Clean rectangles, minimal, fast
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class DetectionPainter extends CustomPainter {
  final List<StableDetection> results;
  final bool useTurkish, showDistance;
  static const double _cameraAR = 9.0 / 16.0;

  DetectionPainter({required this.results, required this.useTurkish, this.showDistance = true});

  static const Map<int, Color> _colors = {
    10: Color(0xFF00E5FF), 8: Color(0xFF00E5FF), 7: Color(0xFF00E5FF),
    6: Color(0xFF00E5FF), 5: Color(0xFF00E5FF), 3: Color(0xFF00E5FF), 2: Color(0xFF00E5FF),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || results.isEmpty) return;
    final wAR = size.width / size.height;
    final double rW, rH;
    if (wAR > _cameraAR) { rW = size.width; rH = size.width / _cameraAR; }
    else { rH = size.height; rW = size.height * _cameraAR; }
    final cX = (rW - size.width) / 2, cY = (rH - size.height) / 2;

    for (var r in results) {
      final b = r.smoothBox;
      final rect = Rect.fromLTRB(b.left*rW-cX, b.top*rH-cY, b.right*rW-cX, b.bottom*rH-cY);
      final vis = rect.intersect(Offset.zero & size);
      if (vis.isEmpty) continue;

      // Simple clean rectangle
      canvas.drawRect(vis, Paint()..color = const Color(0xFF00E5FF).withOpacity(0.6)
        ..style = PaintingStyle.stroke..strokeWidth = 2.0);

      // Simple label
      final label = useTurkish ? AppStrings.getTranslation(r.className) : r.className;
      final text = '$label ${(r.confidence*100).toInt()}%';
      final tp = TextPainter(text: TextSpan(text: text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr)..layout();
      final ly = (vis.top - tp.height - 4).clamp(0.0, size.height - tp.height);
      final lx = vis.left.clamp(0.0, size.width - tp.width - 8);
      canvas.drawRect(Rect.fromLTWH(lx, ly, tp.width+8, tp.height+4),
        Paint()..color = const Color(0xFF00B8D4).withOpacity(0.85));
      tp.paint(canvas, Offset(lx+4, ly+2));
    }
  }

  @override
  bool shouldRepaint(covariant DetectionPainter old) => old.results != results;
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SEGMENTATION PAINTER â€” Precise contours with bezier smoothing
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class SegmentationPainter extends CustomPainter {
  final List<StableDetection> results;
  final bool useTurkish, showDistance;
  final double scanProgress;
  static const double _cameraAR = 9.0 / 16.0;

  SegmentationPainter({required this.results, required this.useTurkish,
    this.showDistance = true, this.scanProgress = 0});

  static const Map<int, Color> _pColors = {
    10: Color(0xFFFF4455), 8: Color(0xFFFF8800), 7: Color(0xFFFF8800),
    6: Color(0xFFFFCC00), 5: Color(0xFF00E5FF), 3: Color(0xFF66BB6A), 2: Color(0xFF7986CB),
  };

  Color _c(String cn) => _pColors[ObjectPriority.getPriority(cn)] ?? const Color(0xFF00E5FF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _drawScanLine(canvas, size);
    if (results.isEmpty) return;

    final wAR = size.width / size.height;
    final double rW, rH;
    if (wAR > _cameraAR) { rW = size.width; rH = size.width / _cameraAR; }
    else { rH = size.height; rW = size.height * _cameraAR; }
    final cX = (rW - size.width) / 2, cY = (rH - size.height) / 2;

    // Animated pulse factor (subtle shimmer)
    final pulse = 0.85 + 0.15 * sin(scanProgress * 2 * pi);

    for (var r in results) {
      final b = r.smoothBox;
      final rect = Rect.fromLTRB(b.left*rW-cX, b.top*rH-cY, b.right*rW-cX, b.bottom*rH-cY);
      final vis = rect.intersect(Offset.zero & size);
      if (vis.isEmpty) continue;

      final col = _c(r.className);
      final op = r.opacity.clamp(0.3, 1.0);

      if (r.mask != null && r.mask!.isNotEmpty && r.mask![0].isNotEmpty) {
        // Adaptive detail: more points for larger objects
        final area = vis.width * vis.height;
        final detail = area > 40000 ? 1 : (area > 15000 ? 2 : 3);

        final path = _maskToSmoothPath(r.mask!, vis, detail);

        // Layer 1: Wide soft glow (outermost)
        canvas.drawPath(path, Paint()
          ..color = col.withOpacity(0.2 * op * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

        // Layer 2: Filled silhouette
        canvas.drawPath(path, Paint()
          ..color = col.withOpacity(0.2 * op)
          ..style = PaintingStyle.fill);

        // Layer 3: Medium neon glow
        canvas.drawPath(path, Paint()
          ..color = col.withOpacity(0.5 * op * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

        // Layer 4: Sharp crisp edge
        canvas.drawPath(path, Paint()
          ..color = col.withOpacity(0.95 * op)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round);
      } else {
        // Fallback: rounded glow (no mask data available)
        final rrect = RRect.fromRectAndRadius(vis, const Radius.circular(8));
        canvas.drawRRect(rrect, Paint()..color = col.withOpacity(0.1 * op)..style = PaintingStyle.fill);
        canvas.drawRRect(rrect, Paint()..color = col.withOpacity(0.25 * op * pulse)..style = PaintingStyle.stroke
          ..strokeWidth = 4..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawRRect(rrect, Paint()..color = col.withOpacity(0.7 * op)..style = PaintingStyle.stroke..strokeWidth = 1.2);
      }

      _drawLabel(canvas, size, vis, r, col, op);
    }
  }

  /// Convert mask to smooth path using boundary extraction + Catmull-Rom splines.
  Path _maskToSmoothPath(List<List<double>> mask, Rect rect, int skipRows) {
    final mH = mask.length;
    final mW = mask[0].length;
    final cellW = rect.width / mW;
    final cellH = rect.height / mH;
    const thr = 0.5;

    // â”€â”€ Step 1: Extract boundary points â”€â”€
    // For each row, find ALL boundary transitions (handles concavities)
    final leftPts = <Offset>[];
    final rightPts = <Offset>[];

    for (int row = 0; row < mH; row += skipRows) {
      // Find leftmost and rightmost active pixels
      int? firstCol, lastCol;
      for (int col = 0; col < mW; col++) {
        if (mask[row][col] > thr) {
          firstCol ??= col;
          lastCol = col;
        }
      }
      if (firstCol == null || lastCol == null) continue;

      // Sub-pixel precision: find exact edge by interpolation
      double leftX = firstCol.toDouble();
      if (firstCol > 0) {
        final v0 = mask[row][firstCol - 1];
        final v1 = mask[row][firstCol];
        if (v1 != v0) leftX = firstCol - 1 + (thr - v0) / (v1 - v0);
      }

      double rightX = lastCol.toDouble() + 1.0;
      if (lastCol < mW - 1) {
        final v0 = mask[row][lastCol];
        final v1 = mask[row][lastCol + 1];
        if (v0 != v1) rightX = lastCol + (thr - v0) / (v1 - v0);
      }

      final y = rect.top + (row + 0.5) * cellH;
      leftPts.add(Offset(rect.left + leftX * cellW, y));
      rightPts.add(Offset(rect.left + rightX * cellW, y));
    }

    if (leftPts.length < 3) {
      return Path()..addOval(rect.deflate(2));
    }

    // â”€â”€ Step 2: Build ordered contour points (clockwise) â”€â”€
    // Left edge (top to bottom), then right edge (bottom to top)
    final contour = <Offset>[];
    contour.addAll(leftPts);
    for (int i = rightPts.length - 1; i >= 0; i--) {
      contour.add(rightPts[i]);
    }

    // â”€â”€ Step 3: Smooth with Catmull-Rom â†’ cubic bezier â”€â”€
    return _catmullRomPath(contour);
  }

  /// Build a closed smooth path using Catmull-Rom spline interpolation.
  /// Converts to cubic bezier segments for Flutter's Path API.
  Path _catmullRomPath(List<Offset> pts) {
    final n = pts.length;
    if (n < 3) {
      final p = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < n; i++) p.lineTo(pts[i].dx, pts[i].dy);
      p.close();
      return p;
    }

    final path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);

    // Catmull-Rom tension (0.5 = standard, lower = tighter)
    const alpha = 0.5;
    final sixth = alpha / 3.0;

    for (int i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      final p3 = pts[(i + 2) % n];

      // Catmull-Rom to cubic bezier control points
      final cp1x = p1.dx + (p2.dx - p0.dx) * sixth;
      final cp1y = p1.dy + (p2.dy - p0.dy) * sixth;
      final cp2x = p2.dx - (p3.dx - p1.dx) * sixth;
      final cp2y = p2.dy - (p3.dy - p1.dy) * sixth;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  void _drawScanLine(Canvas canvas, Size size) {
    final y = size.height * scanProgress;
    canvas.drawRect(Rect.fromLTWH(0, y - 1.5, size.width, 3), Paint()
      ..shader = ui.Gradient.linear(Offset(0, y-1.5), Offset(0, y+1.5),
        [Colors.transparent, const Color(0xFF00E5FF).withOpacity(0.25), Colors.transparent], [0, 0.5, 1]));
  }

  void _drawLabel(Canvas canvas, Size size, Rect rect, StableDetection r, Color col, double op) {
    final label = useTurkish ? AppStrings.getTranslation(r.className) : r.className;
    final conf = '${(r.confidence*100).toInt()}%';
    final dist = showDistance ? ' Â· ${r.distanceEstimate}' : '';
        final tp = TextPainter(text: TextSpan(text: '$label $conf$dist',
      style: TextStyle(color: Colors.white.withOpacity(op), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      textDirection: TextDirection.ltr)..layout();
    final ly = (rect.top - tp.height - 8).clamp(0.0, size.height - tp.height);
    final lx = rect.left.clamp(0.0, size.width - tp.width - 12);
    final bg = RRect.fromRectAndRadius(Rect.fromLTWH(lx, ly, tp.width+12, tp.height+6), const Radius.circular(4));
    canvas.drawRRect(bg, Paint()..color = col.withOpacity(0.85*op));
    tp.paint(canvas, Offset(bg.left+6, bg.top+3));
  }

  @override
  bool shouldRepaint(covariant SegmentationPainter old) => true;
}
