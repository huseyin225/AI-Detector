# AI Vision — Real-Time Object Detection

AI-powered real-time object detection app for Android using YOLO11n.

## Features

### Core Detection
- **Real-time YOLO11n** inference via bundled TFLite model (fully offline)
- **80 COCO object classes** with Turkish translations
- **Temporal stabilization** — EMA-smoothed bounding boxes, no jitter
- **False-positive suppression** — objects must appear in 2+ frames before display
- **Label stability** — prevents rapid flickering between similar classes

### Smart Features
- **Priority-based detection** — person > vehicles > animals > electronics > furniture
- **Distance estimation** — Yakın / Orta / Uzak based on bounding box area
- **Object entry notifications** — announces when high-priority objects enter view
- **Color-coded boxes** — different colors per object category

### Voice System (Turkish TTS)
- **Priority-based announcements** — announces most important object first
- **Per-class cooldown** — prevents spam for the same object (4s cooldown)
- **Global speech cooldown** — prevents overlapping speech (1.5s gap)
- **Natural speech** — Turkish announcements with distance context
- **One-tap toggle** — mute/unmute directly from detection screen

### Settings
- **Performance Mode** ⚡ — higher FPS, slightly lower accuracy
- **Accuracy Mode** 🎯 — more precise detection, normal FPS
- **Confidence threshold** — adjustable 10%–90% with 16 steps
- **Distance display** — toggle on/off
- **Entry notifications** — toggle on/off
- **Dark/Light theme**
- **Turkish/English labels**

### Detection History
- Screenshot capture with detection metadata
- Stored locally (last 50 entries)
- View past detections with timestamps

## Installation

1. Copy `AIVision_Release.apk` to your Android device
2. Enable "Install from unknown sources" if prompted
3. Install and open the app
4. Grant camera permission when requested

## Requirements

- Android 7.0+ (API 24)
- Camera permission
- No internet connection required (model is embedded)

## Architecture

```
lib/
├── main.dart                        # App entry point
├── core/
│   ├── constants/
│   │   ├── app_colors.dart          # Color palette
│   │   └── app_strings.dart         # Turkish translations (80 classes)
│   └── theme/
│       └── app_theme.dart           # Light/Dark themes
├── models/
│   └── detection_history.dart       # History data model
├── services/
│   ├── settings_service.dart        # Persisted settings (SharedPreferences)
│   ├── tts_service.dart             # Priority-based Turkish TTS
│   ├── history_service.dart         # Detection history storage
│   └── detection_stabilizer.dart    # Temporal tracking & smoothing
└── screens/
    ├── splash/splash_screen.dart    # Animated splash
    ├── home/home_screen.dart        # Main menu
    ├── detection/detection_screen.dart  # Camera + YOLO + overlay
    ├── settings/settings_screen.dart    # All settings
    └── history/history_screen.dart      # Past detections
```

## Tech Stack

- **Flutter** + Dart
- **ultralytics_yolo** ^0.3.4 (native CameraX + TFLite inference)
- **YOLO11n** (2.6M params, 6.5 GFLOPs, 640×640 input)
- **flutter_tts** for Turkish voice
- **provider** for state management
- **screenshot** + **shared_preferences** for history

## Device Compatibility

- Tested on: Android phones with rear camera
- Minimum: Android 7.0 (API 24)
- Recommended: Android 10+ for best performance
- All camera aspect ratios supported (16:9, 4:3, etc.)

## Build

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`
