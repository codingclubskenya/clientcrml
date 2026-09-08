import 'package:flutter/foundation.dart';

enum MapTileStyle { street, satellite }

class MapTileConfig {
  static const String _mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  static final ValueNotifier<MapTileStyle> style = ValueNotifier(
    MapTileStyle.street,
  );

  static bool get isMapboxConfigured => _mapboxAccessToken.isNotEmpty;

  static String get urlTemplate {
    return urlTemplateFor(style.value);
  }

  static String urlTemplateFor(MapTileStyle tileStyle) {
    if (!isMapboxConfigured) {
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }

    switch (tileStyle) {
      case MapTileStyle.street:
        return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=$_mapboxAccessToken';
      case MapTileStyle.satellite:
        return 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}?access_token=$_mapboxAccessToken';
    }
  }

  static void setStyle(MapTileStyle tileStyle) {
    if (style.value == tileStyle) return;
    style.value = tileStyle;
  }
}
