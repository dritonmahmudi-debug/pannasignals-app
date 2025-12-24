# Copilot Instructions for signals_app

This guide helps AI coding agents work productively in the `signals_app` codebase. It covers architecture, workflows, conventions, and integration points specific to this project.

## Big Picture Architecture
  - Main code in [`lib/`](lib/) (e.g., `main.dart`, `admin_screen.dart`, `onboarding_screen.dart`).
  - Uses Firebase (core, messaging, auth, analytics, crashlytics) and other packages (see [`pubspec.yaml`](pubspec.yaml)).
  - Assets (icons, splash) in [`assets/icons/`](assets/icons/).
  - FastAPI server in [`backend/main_full.py`](backend/main_full.py) with SQLite DB (`signals.db`).
  - Models: `Signal`, `Device`, `BotStatus`, `PremiumUser` (see DB setup in backend).
  - Push notifications via Firebase Admin SDK; email via SMTP (Namecheap config).
  - Multiple trading bots (forex/crypto, swing/scalp) in [`backend/`](backend/), each as a separate script.

## Developer Workflows
  - Run: `flutter pub get`
  - Generate icons/splash: `flutter pub run flutter_launcher_icons:main` and `flutter pub run flutter_native_splash:create`
  - Build release: `flutter build appbundle --release`
  - Create keystore: `keytool -genkey -v -keystore android\keystore\my-release-key.jks ...`
  - Configure secrets in `android/key.properties` (never commit this file).
  - Start API: `python backend/main_full.py` (ensure dependencies from [`backend/requirements.txt`](backend/requirements.txt) are installed)
  - DB auto-creates tables if missing.
  - Email password is set via `EMAIL_PASSWORD` env var (default in code, but should be changed for production).
  - Each bot script (e.g., `crypto_scalp_bot.py`) is standalone; see comments for usage.

## Project-Specific Conventions

## Integration Points & External Dependencies

## Key Files & Directories


If any section is unclear or missing, please provide feedback or specify which workflows, conventions, or integration points need more detail.
