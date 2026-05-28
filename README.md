# CryptWhisper 🎙️🔐

[![Flutter](https://img.shields.io/badge/Frontend-Flutter%20%2F%20Dart-02569B?logo=flutter&logoColor=white&style=for-the-badge)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Backend-Python%20%2F%20Flask-3776AB?logo=python&logoColor=white&style=for-the-badge)](https://www.python.org)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Prototype-green?style=for-the-badge)](https://github.com/Nandinivora18/Voice-unlock)

> An offline, zero-trust credential vault secured by hybrid voice biometrics. It protects secrets using a dual-gate authentication flow: a vocal passphrase plus a biometric voice fingerprint.

---

## ✨ Why this project stands out

* **Fully offline security** — no cloud storage, no third-party voice services.
* **Hybrid voice authentication** — combines text matching and biometric voice signature.
* **Resilient against replay/spoofing** — uses spectral voice features and timing patterns.
* **Flutter + Python** — modern cross-platform UI with a local backend for signal processing.
* **Easy demo setup** — install dependencies and run both backend and Flutter app.

---

## 🚀 Features

* **Dual-Gate Unlock**: requires both phrase recognition and speaker verification.
* **76-Dimensional Voice Fingerprint**: MFCC + delta features + mean/variance.
* **Hybrid Matching Engine**: Cosine similarity and Dynamic Time Warping (DTW).
* **Offline Speech Recognition**: powered by Vosk locally.
* **AES-256 Ferro encryption** for secure vault data.
* **Automatic lockout** after repeated failed attempts.
* **Cross-platform app structure**: Flutter frontend and Python backend.

---

## 📂 Repository Structure

```text
aprilcapstone/
├─ android/              # Flutter Android project files
├─ ios/                  # Flutter iOS project files
├─ macos/                # Flutter macOS project files
├─ lib/                  # Flutter app source code
├─ python_backend/       # Offline voice backend and biometric engine
├─ test/                 # Flutter widget tests
├─ web/                  # Web assets and manifest
├─ pubspec.yaml          # Flutter package configuration
└─ README.md             # Project overview and setup guide
```

---

## 🧪 Run it locally

### Backend
```bash
cd python_backend
pip install -r requirements.txt
python server.py
```

### Frontend
```bash
flutter pub get
flutter run
```

> Start the Python server first, then launch the Flutter app.

---

## 💡 Notes for reviewers

* The UI is built with Flutter.
* The voice biometric library uses Vosk and `librosa`.
* The project is designed for offline security and local verification.

---

## 🙌 Want to contribute?

If you want to help improve the app, please open an issue or send a pull request.

---

## 📝 License

This project is available under the [MIT License](LICENSE).
