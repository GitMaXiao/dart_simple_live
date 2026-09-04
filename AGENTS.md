# Repository Guidelines

## Project Structure & Module Organization

This repository contains four related Dart/Flutter packages; run package commands from the package you change.

- `simple_live_core/`: platform APIs, stream resolution, danmaku clients, models, and the plugin runtime. Bundled packages live in `packages/`.
- `simple_live_app/`: mobile and desktop Flutter client. Feature screens are under `lib/modules/`; shared widgets, services, routes, requests, and models have matching `lib/` directories.
- `simple_live_tv_app/`: Android TV-focused Flutter client with remote-control navigation.
- `simple_live_console/`: command-line harness for exercising the core library.
- `assets/`: repository-level screenshots and release metadata; `docs/` contains plugin documentation and examples.

Tests belong in each package's `test/` directory. Platform projects (`android/`, `ios/`, `windows/`, `macos/`, and `linux/`) should only contain platform-specific integration changes.

## Build, Test, and Development Commands

The app packages pin Flutter 3.38.3 in `.fvmrc`; use FVM when available.

```bash
cd simple_live_app
fvm flutter pub get                 # install dependencies
fvm flutter run -d windows          # run on a selected device
fvm flutter analyze                 # apply analyzer and Flutter lints
fvm flutter test                    # run this package's tests
fvm flutter build apk --release     # create an Android release APK
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

For `simple_live_tv_app`, use the same Flutter commands from that directory. In `simple_live_core` or `simple_live_console`, use `dart pub get`, `dart analyze`, `dart test`, and `dart run bin/simple_live_console.dart` as applicable.

## Coding Style & Naming Conventions

Format Dart with `dart format .` (standard two-space indentation). Follow `package:flutter_lints/flutter.yaml` in UI packages and `package:lints/recommended.yaml` in Dart packages. Use `snake_case.dart` filenames, `UpperCamelCase` types/widgets, and `lowerCamelCase` members. Keep feature pages and controllers together under `lib/modules/<feature>/`. Regenerate and commit tracked `*.g.dart` files after changing Hive models; do not hand-edit generated code.

## Testing Guidelines

Use `flutter_test` for UI packages and `package:test` for Dart packages. Name files `*_test.dart`, group related scenarios, and add regression coverage near the affected package. Core network tests may depend on live services, so document any skipped or environment-sensitive cases. No coverage threshold is enforced; prioritize plugin parsing, API normalization, and controller behavior.

## Commit & Pull Request Guidelines

History follows Conventional Commits: `feat(player): ...`, `fix(sync): ...`, `docs: ...`, `chore(release): ...`, and `ci: ...`. Keep commits focused and use a scope when it clarifies the affected feature. Pull requests should explain behavior and affected platforms, link related issues, list analyze/test results, and include screenshots or recordings for UI changes. Never commit signing keys, `key.properties`, credentials, tokens, or local build output.
