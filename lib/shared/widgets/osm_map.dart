import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Tiles do OpenStreetMap, comuns a todos os mapas do app.
///
/// A política de uso dos tiles da OSMF pede um User-Agent que identifique o
/// app: é o pacote publicado, `br.com.compy.app` (antes ia `br.com.compy.mvp`).
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'br.com.compy.app',
    );

/// "© OpenStreetMap contributors", sempre visível no canto do mapa, como
/// exigem a licença ODbL e as diretrizes de atribuição da OSMF. Vai como
/// filho do `FlutterMap`, logo depois de [osmTileLayer]. Em mapa estreito ou
/// com texto ampliado, encolhe em vez de transbordar.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () => launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '© ${AppStrings.mapsAttribution}',
                  maxLines: 1,
                  style: TextStyle(fontSize: 10, color: AppColors.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
