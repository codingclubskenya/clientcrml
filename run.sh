#!/bin/bash
#
# Helper script to run the Flutter app with Mapbox access token.
#
# Usage:
#   ./run.sh                  # Run with token from env var MAPBOX_ACCESS_TOKEN
#   MAPBOX_ACCESS_TOKEN=pk.xxx ./run.sh  # Pass token inline
#   ./run.sh --dart-define=OTHER=value  # Pass additional define flags
#
# If MAPBOX_ACCESS_TOKEN is not set, the app falls back to OpenStreetMap tiles.

set -e

# Check for MAPBOX_ACCESS_TOKEN
if [ -z "$MAPBOX_ACCESS_TOKEN" ]; then
  echo "Warning: MAPBOX_ACCESS_TOKEN is not set."
  echo "The app will use OpenStreetMap tiles as fallback."
  echo "Set the token: export MAPBOX_ACCESS_TOKEN=pk.your_token_here"
  echo "Or: MAPBOX_ACCESS_TOKEN=pk.your_token_here ./run.sh"
  echo ""
fi

# Build the dart-define flag
DART_DEFINES=""
if [ -n "$MAPBOX_ACCESS_TOKEN" ]; then
  DART_DEFINES="--dart-define=MAPBOX_ACCESS_TOKEN=$MAPBOX_ACCESS_TOKEN $DART_DEFINES"
fi

# Pass through any additional dart-define arguments
EXTRA_DEFINES="$*"

echo "Starting Flutter app..."
flutter run $DART_DEFINES $EXTRA_DEFINES
