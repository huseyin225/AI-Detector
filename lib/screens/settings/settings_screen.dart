import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../core/constants/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: Consumer<SettingsService>(builder: (context, s, _) {
        return ListView(padding: const EdgeInsets.all(16), children: [
          _h(context, 'Algılama Modu', Icons.auto_awesome),
          _modeCards(context, s),
          const SizedBox(height: 8),
          SwitchListTile(title: const Text('Performans Modu'),
            subtitle: Text(s.performanceMode ? '⚡ Hızlı FPS' : '🎯 Hassas algılama'),
            secondary: Icon(s.performanceMode ? Icons.speed : Icons.gps_fixed,
              color: s.performanceMode ? Colors.orange : AppColors.success),
            value: s.performanceMode, onChanged: s.togglePerformanceMode),
          _slider(s),
          const Divider(height: 32),

          _h(context, 'Akıllı Özellikler', Icons.psychology),
          SwitchListTile(title: const Text('Kişi Takibi'), subtitle: const Text('Kişileri kilitle ve özel vurgula'),
            value: s.personTracking, onChanged: s.togglePersonTracking),
          SwitchListTile(title: const Text('Mesafe Tahmini'), subtitle: const Text('Yakın / Orta / Uzak'),
            value: s.showDistance, onChanged: s.toggleShowDistance),
          SwitchListTile(title: const Text('Düşük Işık Uyarısı'), subtitle: const Text('Karanlık ortamda uyar'),
            value: s.lowLightWarning, onChanged: s.toggleLowLightWarning),
          SwitchListTile(title: const Text('Sahne Özeti'), subtitle: const Text('Periyodik sahne analizi'),
            value: s.sceneSummary, onChanged: s.toggleSceneSummary),
          SwitchListTile(title: const Text('Yön Rehberliği'), subtitle: const Text('Nesne konumunu sesli bildir'),
            value: s.spatialGuidance, onChanged: s.toggleSpatialGuidance),
          const Divider(height: 32),

          _h(context, 'AI Sahne Açıklaması (Claude)', Icons.auto_awesome),
          SwitchListTile(title: const Text('LLM Sahne Analizi'), 
            subtitle: const Text('Claude API ile doğal dilde sahne açıklaması'),
            value: s.llmEnabled, onChanged: s.toggleLlmEnabled),
          if (s.llmEnabled) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Anthropic API Key',
                hintText: 'sk-ant-...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.key),
                suffixIcon: s.llmApiKey.isNotEmpty 
                  ? const Icon(Icons.check_circle, color: Colors.green) : null,
              ),
              obscureText: true,
              controller: TextEditingController(text: s.llmApiKey),
              onChanged: s.setLlmApiKey,
            ),
          ),
          const Divider(height: 32),

          _h(context, 'Ses Sistemi', Icons.record_voice_over),
          SwitchListTile(title: const Text('Sesli Asistan'), subtitle: const Text('Nesneleri ve sahneyi sesli açıkla'),
            value: s.voiceEnabled, onChanged: s.toggleVoice),
          SwitchListTile(title: const Text('Giriş Bildirimi'), subtitle: const Text('Yeni nesne girince duyur'),
            value: s.entryNotify, onChanged: s.voiceEnabled ? s.toggleEntryNotify : null),
          SwitchListTile(title: const Text('Türkçe İsimler'), subtitle: const Text('Türkçe etiket ve ses'),
            value: s.useTurkishLabels, onChanged: s.toggleTurkishLabels),
          const Divider(height: 32),

          _h(context, 'Görünüm', Icons.palette),
          SwitchListTile(title: const Text('Karanlık Mod'), value: s.isDarkMode, onChanged: s.toggleDarkMode),
          const Divider(height: 32),

          _h(context, 'Sistem', Icons.info_outline),
          _info('Algılama', 'YOLO11n (10.2 MB)'), _info('Segmentasyon', 'YOLO11n-seg (11.2 MB)'),
          _info('Çevrimdışı', 'Model gömülü'), _info('Takip', 'Hız tahmini + 3s bellek'),
          _info('LLM', 'Claude Sonnet (isteğe bağlı)'),
          const SizedBox(height: 24),
        ]);
      }),
    );
  }

  Widget _modeCards(BuildContext ctx, SettingsService s) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      Expanded(child: _card(ctx, Icons.center_focus_strong, 'Algılama', 'Hızlı kutu', !s.segmentationMode, () => s.toggleSegmentationMode(false))),
      const SizedBox(width: 12),
      Expanded(child: _card(ctx, Icons.blur_on, 'Segmentasyon', 'Piksel maskesi', s.segmentationMode, () => s.toggleSegmentationMode(true))),
    ]),
  );

  Widget _card(BuildContext ctx, IconData icon, String t, String sub, bool sel, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sel ? AppColors.primary.withOpacity(0.15) : Theme.of(ctx).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sel ? AppColors.primary : Colors.grey.withOpacity(0.3), width: sel ? 2 : 1)),
      child: Column(children: [
        Icon(icon, size: 28, color: sel ? AppColors.primary : Colors.grey),
        const SizedBox(height: 8),
        Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? AppColors.primary : null)),
        Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ));

  Widget _slider(SettingsService s) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Güven Eşiği'),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('${(s.threshold*100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
      ]),
      Slider(value: s.threshold, min: 0.1, max: 0.9, divisions: 16, activeColor: AppColors.primary, onChanged: s.setThreshold),
    ]),
  );

  Widget _h(BuildContext ctx, String t, IconData i) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(children: [
      Icon(i, size: 20, color: AppColors.primary), const SizedBox(width: 8),
      Text(t, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
    ]),
  );

  Widget _info(String t, String s) => ListTile(dense: true,
    title: Text(t, style: const TextStyle(fontSize: 13)),
    subtitle: Text(s, style: const TextStyle(fontSize: 12)),
    trailing: const Icon(Icons.check_circle, color: Colors.green, size: 18));
}
