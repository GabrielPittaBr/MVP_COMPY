import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

/// Cabeçalho da home: avatar à esquerda, título "Compy" no centro,
/// engrenagem à direita, e abaixo a saudação "Oi, {nome}".
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({required this.userName, super.key});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceMuted,
              backgroundImage: CachedNetworkImageProvider(
                AppAssets.avatar(userName),
              ),
            ),
            const Spacer(),
            const Text(
              AppStrings.appName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.onSurface,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${AppStrings.homeGreetingPrefix} $userName',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
