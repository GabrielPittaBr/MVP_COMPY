import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/constants/app_geo.dart';
import '../../../../core/theme/app_colors.dart';

/// Cartão "Explore locais" na home: mostra um snapshot do mapa de Taquara
/// e leva para a tela de mapa completa ao tocar.
class ExploreMapCard extends StatelessWidget {
  const ExploreMapCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: <Widget>[
          SizedBox(
            height: 140,
            width: double.infinity,
            child: AbsorbPointer(
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: AppGeo.taquaraCenter,
                  initialZoom: 13.5,
                  interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'br.com.compy.mvp',
                  ),
                ],
              ),
            ),
          ),
          // Overlay clicável (a sobreposição clicável fica fora do AbsorbPointer).
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.outlineSoft),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
