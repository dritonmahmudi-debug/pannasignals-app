# signals_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:


For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
## Fixing launcher icon & splash issues ✅

If the app icon shows a white square, or the splash shows a white background (instead of the dark app background), do the following:

- Make sure you have a **transparent** foreground logo PNG (preferably 1024×1024) with no white backdrop and place it at `assets/icons/panna_signals_foreground.png`.
- The project already points launcher icons and native splash to this foreground file and uses `#0B0F19` as the splash/background color.
- Regenerate icons and splash locally:

```powershell
flutter pub get
flutter pub run flutter_launcher_icons:main
flutter pub run flutter_native_splash:create
```

If you still see a white background, replace the foreground image with a higher-resolution transparent PNG (or an SVG exported to PNG) that does not contain the white circle/backdrop, then rerun the commands above.

Note: I also updated the iOS `LaunchScreen.storyboard` to use the dark background color (`#0B0F19`) so the initial launch screen matches the app theme instead of showing white. If you still see a white flash on iOS, try a clean build of the app and test on a device/simulator.

If you want me to replace and generate new icon art (transparent PNG versions), provide the source/logo files (SVG or a clean PNG) and I can prepare them here.

## Release signing (keystore) - quick setup

To publish to the Play Store you will need a release keystore. Create one locally and configure `android/key.properties` (never commit this file).

Example:

```text
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=../keystore/my-release-key.jks
```

Steps to create keystore (on Windows / Powershell):

```powershell
mkdir android\keystore
keytool -genkey -v -keystore android\keystore\my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias your_key_alias
```

Add `android/key.properties` (not committed), then build the aab:

```powershell
flutter build appbundle --release
```

If you'd like, I can prepare a CI job that uses secrets to sign and upload builds to the Play Console for you.
