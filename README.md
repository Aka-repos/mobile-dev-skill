# 📱 mobile-dev-skill

A Claude Code skill for mobile development across **Flutter**, **Kotlin/Android**, **Swift/iOS**, and **React Native**. Install it once and Claude automatically applies platform-specific patterns, architecture, and best practices to your project.

---

## ✨ What it does

- **Detects your platform automatically** from file context (`pubspec.yaml` → Flutter, `build.gradle` → Kotlin, `Info.plist` → Swift, `metro.config` → React Native)
- Generates **idiomatic, production-ready code** — not generic copy-paste
- Covers architecture, state management, networking, Firebase, navigation, and common bugs
- Loads only the relevant reference for your platform — no bloat

---

## 📦 Install

```bash
claude skills install https://github.com/Aka-repos/mobile-dev-skill/raw/main/output/mobile-dev-skill.skill
```

---

## 🚀 What it covers

### Flutter / Dart
- Clean Architecture folder structure
- BLoC and Riverpod state management patterns
- GoRouter navigation
- Dio networking with auth interceptors
- Common fixes: RenderFlex overflow, async context gaps, unbounded ListView

### Kotlin / Android
- MVVM + Clean Architecture
- ViewModel + StateFlow
- Hilt dependency injection
- Retrofit + OkHttp setup
- Jetpack Compose patterns

### Swift / iOS
- MVVM with SwiftUI
- async/await networking
- Keychain token storage
- Dependency injection with factory pattern
- Retain cycle prevention

### React Native / Expo
- Feature-based folder structure
- Zustand state management
- Axios with interceptors
- React Navigation v6
- FlashList for performance

### Firebase (all platforms)
- Auth with anonymous → linked account upgrade
- Firestore real-time listeners
- FCM push notifications
- Security rules

### REST API integration
- Response envelope pattern
- Token refresh queue
- Pagination strategies (offset, cursor, keyset)

---

## 💡 Example prompts

```
Build a login screen with Firebase Auth in Flutter
```
```
How do I collect StateFlow properly in a Fragment?
```
```
I'm getting RenderFlex overflow on my Row widget
```
```
Set up Retrofit with a token refresh interceptor in Kotlin
```
```
Should I use Flutter or React Native for my project?
```

---

## 🗂 Structure

```
mobile-dev-skill/
├── SKILL.md                  # Main skill — platform detection & workflow
└── references/
    ├── flutter.md
    ├── kotlin-android.md
    ├── swift-ios.md
    ├── react-native.md
    ├── firebase-mobile.md
    └── rest-mobile.md
```

---

## 🤝 Contributing

PRs welcome. If you want to improve a platform reference or add a new section (testing, CI/CD, app store deployment), open a PR against the relevant file in `mobile-dev-skill/references/`.

---

Made with Claude Code · [Aka-repos](https://github.com/Aka-repos)
