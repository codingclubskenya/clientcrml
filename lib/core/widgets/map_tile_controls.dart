import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../config/map_tile_config.dart';

class MapTileLayer extends StatelessWidget {
  const MapTileLayer({
    super.key,
    required this.userAgentPackageName,
    this.maxNativeZoom = 19,
    this.panBuffer = 2,
  });

  final String userAgentPackageName;
  final int maxNativeZoom;
  final int panBuffer;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapTileStyle>(
      valueListenable: MapTileConfig.style,
      builder: (context, tileStyle, _) {
        return TileLayer(
          urlTemplate: MapTileConfig.urlTemplateFor(tileStyle),
          userAgentPackageName: userAgentPackageName,
          maxNativeZoom: maxNativeZoom,
          panBuffer: panBuffer,
        );
      },
    );
  }
}

class MapStyleSwitcher extends StatelessWidget {
  const MapStyleSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapTileStyle>(
      valueListenable: MapTileConfig.style,
      builder: (context, tileStyle, _) {
        return Material(
          color: Colors.white,
          elevation: 3,
          borderRadius: BorderRadius.circular(999),
          child: ToggleButtons(
            borderRadius: BorderRadius.circular(999),
            isSelected: [
              tileStyle == MapTileStyle.street,
              tileStyle == MapTileStyle.satellite,
            ],
            onPressed: (index) {
              MapTileConfig.setStyle(
                index == 0 ? MapTileStyle.street : MapTileStyle.satellite,
              );
            },
            constraints: const BoxConstraints(minHeight: 36, minWidth: 84),
            selectedColor: Colors.white,
            fillColor: Theme.of(context).colorScheme.primary,
            color: Theme.of(context).colorScheme.onSurface,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('Street'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('Satellite'),
              ),
            ],
          ),
        );
      },
    );
  }
}
