<h1 align="center">🤖 AI Vision — Real-Time Object Detection</h1>

<p align="center">
  An offline, real-time object detection Android app powered by <strong>YOLO11n</strong> and Flutter.<br/>
  Detects 80 COCO object classes with Turkish voice announcements, temporal stabilization, and rich customization.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/YOLO11n-TFLite-FF6F00?logo=tensorflow&logoColor=white" alt="YOLO11n"/>
  <img src="https://img.shields.io/badge/Android-7.0%2B-3DDC84?logo=android&logoColor=white" alt="Android"/>
  <img src="https://img.shields.io/badge/Offline-100%25-success" alt="Offline"/>
  <img src="https://img.shields.io/badge/Version-1.0.0-blue" alt="Version"/>
</p>

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation (APK)](#installation-apk)
  - [Building from Source](#building-from-source)
- [How It Works](#-how-it-works)
- [Project Structure](#-project-structure)
- [Device Compatibility](#-device-compatibility)
- [Configuration & Settings](#-configuration--settings)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🔍 Overview

**AI Vision** is a fully offline Android application that performs real-time object detection directly on-device using the **YOLO11n** neural network model compiled to TFLite. It is designed to be fast, accurate, and accessible — featuring Turkish text-to-speech (TTS) announcements, distance estimation, and a detection history system.

No internet connection is ever required. The AI model is embedded within the app.

---

## ✨ Features

### 🎯 Core Detection

| Feature | Description |
|---|---|
| **YOLO11n Inference** | Real-time on-device detection via TFLite — 100% offline |
| **80 COCO Classes** | Detects people, vehicles, animals, electronics, furniture, and more |
| **Turkish Translations** | All 80 class labels available in Turkish and English |
| **Temporal Stabilization** | EMA-smoothed bounding boxes eliminate jitter between frames |
| **False-Positive Suppression** | Objects must appear in 2+ consecutive frames before being displayed |
| **Label Stability** | Prevents rapid flickering between visually similar class labels |

### 🧠 Smart Detection

| Feature | Description |
|---|---|
| **Priority System** | `Person > Vehicles > Animals > Electronics > Furniture` |
| **Distance Estimation** | Estimates distance as *Yakın / Orta / Uzak* (Near / Medium / Far) based on bounding box area |
| **Entry Notifications** | Announces when a high-priority object enters the camera view |
| **Color-Coded Boxes** | Each object category is highlighted with a distinct color |

### 🔊 Voice System (Turkish TTS)

| Feature | Description |
|---|---|
| **Priority Announcements** | Announces the most important detected object first |
| **Per-Class Cooldown** | 4-second cooldown per object class to prevent repetitive announcements |
| **Global Speech Gap** | 1.5-second minimum gap between any two announcements |
| **Natural Language** | Turkish announcements include distance context (e.g., *"Yakında bir insan var"*) |
| **One-Tap Mute** | Instantly mute/unmute voice from the detection screen |

### ⚙️ Settings & Customization

| Setting | Details |
|---|---|
| **Performance Mode ⚡** | Higher FPS, slightly reduced accuracy |
| **Accuracy Mode 🎯** | Maximum detection precision, standard FPS |
| **Confidence Threshold** | Adjustable from 10% to 90% in 16 steps |
| **Distance Display** | Toggle distance labels on/off |
| **Entry Notifications** | Toggle voice notifications on/off |
| **Theme** | Dark and Light mode support |
| **Language** | Switch between Turkish and English class labels |

### 🗂️ Detection History

- Capture screenshots with full detection metadata
- Stored locally on-device (last 50 entries)
- View past detections with timestamps and class details

---

## 🏗️ Architecture

The app follows a **service-oriented** architecture with clearly separated concerns:

```
┌─────────────────────────────────────────┐
│              UI Layer (Screens)          │
│  Splash → Home → Detection → Settings   │
│                      ↕                  │
│         History Screen (Gallery)        │
└────────────────┬────────────────────────┘
                 │ Provider (State Management)
┌────────────────▼────────────────────────┐
│              Service Layer               │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │ TTS Service  │  │ Settings Service│  │
│  └──────────────┘  └─────────────────┘  │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │History Svc   │  │ Stabilizer Svc  │  │
│  └──────────────┘  └─────────────────┘  │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│           YOLO11n + TFLite              │
│     (Bundled model — no network)         │
└─────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

| Technology | Version | Purpose |
|---|---|---|
| **Flutter** | 3.x | Cross-platform UI framework |
| **Dart** | 3.x | Primary programming language |
| **ultralytics_yolo** | ^0.3.4 | Native CameraX + TFLite YOLO inference |
| **YOLO11n** | — | 2.6M params, 6.5 GFLOPs, 640×640 input |
| **flutter_tts** | ^4.2.0 | Turkish text-to-speech voice system |
| **provider** | ^6.1.0 | Lightweight state management |
| **shared_preferences** | ^2.3.0 | Persistent app settings |
| **screenshot** | ^3.0.0 | In-app screenshot capture |
| **google_fonts** | ^6.2.0 | Custom typography |
| **intl** | ^0.19.0 | Internationalization & date formatting |
| **path_provider** | ^2.1.0 | File system access for history |
| **http** | ^1.2.0 | HTTP utilities |

---

## 🚀 Getting Started

### Prerequisites

- **For APK install:** Any Android 7.0+ device
- **For building from source:**
  - [Flutter SDK](https://flutter.dev/docs/get-started/install) (Dart SDK ^3.11.5)
  - Android Studio or VS Code with Flutter extension
  - A connected Android device or emulator (API 24+)

### Installation (APK)

The easiest way to get started is by installing the pre-built APK:

1. Download `AIVision_Release.apk` from the [Releases](../../releases) page
2. Transfer the file to your Android device
3. On your device, go to **Settings → Security → Unknown Sources** and enable it
4. Open the APK file and tap **Install**
5. Launch **AI Vision** and grant the camera permission when prompted

> **Note:** No internet connection is needed at any point. The AI model is bundled inside the app.

### Building from Source

```bash
# 1. Clone the repository
git clone https://github.com/your-username/ai-vision.git
cd ai-vision

# 2. Install Flutter dependencies
flutter pub get

# 3. Run on a connected device (debug mode)
flutter run

# 4. Build a release APK
flutter build apk --release
```

The release APK will be output to:

```
build/app/outputs/flutter-apk/app-release.apk
```

---

## ⚙️ How It Works

### Detection Pipeline

```
Camera Frame
     │
     ▼
CameraX (Native Android)
     │
     ▼
YOLO11n TFLite Model (on-device)
     │  └─ 80-class confidence scores + bounding boxes
     ▼
DetectionStabilizer Service
     │  ├─ EMA bounding box smoothing
     │  ├─ 2-frame appearance threshold (anti-flicker)
     │  └─ Label stability filter
     ▼
Priority Ranking + Distance Estimation
     │
     ▼
UI Overlay + TTS Announcements
```

### Distance Estimation Logic

Distance is estimated from the **normalized bounding box area** relative to the frame:

| Area Threshold | Label (EN) | Label (TR) |
|---|---|---|
| > 25% of frame | Close | Yakın |
| 8% – 25% of frame | Medium | Orta |
| < 8% of frame | Far | Uzak |

---

## 📁 Project Structure

```
ai_detector/
├── android/                              # Native Android project files
├── assets/
│   ├── images/                           # App images and icons
│   └── models/                           # Bundled YOLO11n TFLite model
├── lib/
│   ├── main.dart                         # App entry point & initialization
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart           # Global color palette
│   │   │   └── app_strings.dart          # 80-class label translations (TR/EN)
│   │   └── theme/
│   │       └── app_theme.dart            # Light & Dark theme definitions
│   ├── models/
│   │   └── detection_history.dart        # Data model for history entries
│   ├── services/
│   │   ├── settings_service.dart         # Persisted settings via SharedPreferences
│   │   ├── tts_service.dart              # Priority-based Turkish TTS engine
│   │   ├── history_service.dart          # Detection history read/write
│   │   └── detection_stabilizer.dart     # Temporal tracking & EMA smoothing
│   ├── screens/
│   │   ├── splash/splash_screen.dart     # Animated splash screen
│   │   ├── home/home_screen.dart         # Main menu
│   │   ├── detection/detection_screen.dart  # Camera feed + YOLO overlay
│   │   ├── settings/settings_screen.dart    # User settings panel
│   │   └── history/history_screen.dart      # Past detection gallery
│   └── widgets/                          # Reusable UI components
├── test/                                 # Unit & widget tests
├── pubspec.yaml                          # Flutter dependencies & assets
└── README.md
```

---

## 📱 Device Compatibility

| Requirement | Specification |
|---|---|
| **Minimum Android** | 7.0 (API Level 24) |
| **Recommended Android** | 10.0+ (API Level 29+) |
| **Camera** | Rear-facing camera required |
| **Aspect Ratios** | 16:9, 4:3, and all standard ratios |
| **Internet** | Not required — fully offline |
| **Tested On** | Android phones with standard rear cameras |

> **Performance Tip:** For best FPS, use a device running Android 10+ with a modern SoC. Enable **Performance Mode** in Settings to prioritize frame rate.

---

## 🎛️ Configuration & Settings

All settings are persisted automatically between sessions using `SharedPreferences`.

| Setting | Default | Range / Options |
|---|---|---|
| Detection Mode | Accuracy 🎯 | Performance ⚡ / Accuracy 🎯 |
| Confidence Threshold | 50% | 10% – 90% (16 steps) |
| Voice Announcements | Enabled | On / Off |
| Distance Display | Enabled | On / Off |
| Entry Notifications | Enabled | On / Off |
| Label Language | Turkish | Turkish / English |
| App Theme | System | Light / Dark |

---

## 🤝 Contributing

Contributions are welcome! To contribute:

1. **Fork** this repository
2. **Create** a feature branch: `git checkout -b feature/your-feature-name`
3. **Commit** your changes: `git commit -m 'feat: add your feature'`
4. **Push** to the branch: `git push origin feature/your-feature-name`
5. **Open** a Pull Request

Please ensure your code follows the existing style and passes `flutter analyze` before submitting.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<p align="center">Built with ❤️ using Flutter & YOLO11n</p>
