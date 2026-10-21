# dehus

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Map tiles

The app supports Mapbox and OpenStreetMap tile providers. Mapbox requires an access token.

### Using Mapbox

Build or run with the `--dart-define` flag:

```bash
# Run with Mapbox tiles
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token_here

# Build for release
flutter build apk --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token_here
```

Alternatively, use the helper script:

```bash
export MAPBOX_ACCESS_TOKEN=pk.your_token_here
./run.sh
```

The token must have access to the `mapbox/streets-v12` and `mapbox/satellite-streets-v12` styles. You can verify your token at https://account.mapbox.com/.

### Fallback

If `MAPBOX_ACCESS_TOKEN` is not provided, the app automatically falls back to OpenStreetMap tiles. No additional configuration is needed.
