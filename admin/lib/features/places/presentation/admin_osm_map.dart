import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Tiles do OpenStreetMap, comuns a todos os mapas do painel.
TileLayer adminOsmTileLayer() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'br.com.compy.admin',
);

/// Atribuição exigida pela licença do OpenStreetMap; vai como filho direto do
/// `Stack` que envolve o `FlutterMap`.
class AdminOsmAttribution extends StatelessWidget {
  const AdminOsmAttribution({super.key});

  @override
  Widget build(BuildContext context) => const Positioned(
    right: 8,
    bottom: 8,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white70),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text('© OpenStreetMap contributors'),
        ),
      ),
    ),
  );
}
