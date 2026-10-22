import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/sport_place.dart';
import 'place_rating_row.dart';

/// Bottom sheet exibido ao tocar em um pin (RF04 — informações do local +
/// ação de criar evento ali).
///
/// D11: "Favoritar" saiu — não existe modelo de local favorito e botão
/// inerte é pior que botão ausente. "Compartilhar" voltou junto com o chat
/// funcional, que é para onde um local compartilhado vai.
class PlaceDetailsSheet extends StatelessWidget {
  const PlaceDetailsSheet({
    required this.place,
    required this.onCreateEvent,
    required this.onShare,
    super.key,
  });

  final SportPlace place;
  final VoidCallback onCreateEvent;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      // Sem `expand: false` o sheet ocupa o Stack inteiro e o Scrollable
      // interno engole os toques na área transparente acima do card —
      // era isso que impedia de tocar no mapa para fechá-lo.
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: <Widget>[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PlaceImageCarousel(place: place),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PlaceAccessBadge(place: place),
                    if (place.accessType == PlaceAccessType.private &&
                        place.contactPhone != null) ...<Widget>[
                      const SizedBox(height: 6),
                      _ContactPhone(place: place),
                    ],
                    if (place.status == PlaceStatus.inactive) ...<Widget>[
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Local inativo',
                        child: const Chip(
                          avatar: Icon(Icons.info_outline, size: 18),
                          label: Text('Local inativo'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      // Endereço completo só quando conferido; senão a
                      // cidade já situa o local.
                      place.address.street.isEmpty
                          ? place.city
                          : place.formattedAddress,
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Esportes praticáveis — os mesmos que o seletor de
                    // "Criar evento" oferece para este local.
                    _SportsWrap(place: place),
                    const SizedBox(height: 12),
                    PlaceRatingRow(placeId: place.id),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _ActionButton(
                          icon: Icons.add,
                          label: AppStrings.eventCreate,
                          onTap: place.status == PlaceStatus.active
                              ? onCreateEvent
                              : null,
                        ),
                        const SizedBox(width: 40),
                        _ActionButton(
                          icon: Icons.share_outlined,
                          label: AppStrings.mapsShare,
                          onTap: place.status == PlaceStatus.active
                              ? onShare
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      AppStrings.mapsPlaceInfo,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      place.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaceImageCarousel extends StatefulWidget {
  const _PlaceImageCarousel({required this.place});

  final SportPlace place;

  @override
  State<_PlaceImageCarousel> createState() => _PlaceImageCarouselState();
}

class _PlaceImageCarouselState extends State<_PlaceImageCarousel> {
  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.place.gallery;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final image = images[index];
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CachedNetworkImage(
                    imageUrl: image.url,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surfaceMuted,
                      child: Icon(
                        widget.place.primarySport.icon,
                        size: 60,
                        color: widget.place.primarySport.color,
                      ),
                    ),
                  ),
                  if (image.source?.isNotEmpty == true)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.68,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(0, 0, 0, 0.58),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            child: Text(
                              image.source!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                height: 1.1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (images.length > 1)
                    Positioned(
                      left: 10,
                      bottom: 14,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List<Widget>.generate(images.length, (dot) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: dot == _currentPage ? 16 : 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: dot == _currentPage
                                  ? Colors.white
                                  : Colors.white70,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlaceAccessBadge extends StatelessWidget {
  const _PlaceAccessBadge({required this.place});

  final SportPlace place;

  @override
  Widget build(BuildContext context) {
    final label = switch (place.accessType) {
      PlaceAccessType.public => AppStrings.mapsPlacePublic,
      PlaceAccessType.private => AppStrings.mapsPlacePrivate,
      null => AppStrings.mapsPlaceTypeUnknown,
    };
    final icon = switch (place.accessType) {
      PlaceAccessType.public => Icons.public,
      PlaceAccessType.private => Icons.lock_outline,
      null => Icons.help_outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 14,
            color: AppColors.onSurfaceMuted,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactPhone extends StatelessWidget {
  const _ContactPhone({required this.place});

  final SportPlace place;

  @override
  Widget build(BuildContext context) {
    final phone = place.contactPhone!;
    return Semantics(
      button: true,
      label: '${AppStrings.mapsPlaceContact}: ${_formatPlacePhone(phone)}',
      child: InkWell(
        onTap: () async {
          try {
            await launchUrl(
              Uri(scheme: 'tel', path: phone),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {
            // A device without a dialer still retains the readable number.
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.phone_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                _formatPlacePhone(phone),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPlacePhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return phone;
  final ddd = digits.substring(0, 2);
  final subscriber = digits.substring(2);
  final splitAt = subscriber.length > 8 ? 5 : 4;
  return '($ddd) ${subscriber.substring(0, splitAt)}-${subscriber.substring(splitAt)}';
}

class _SportsWrap extends StatelessWidget {
  const _SportsWrap({required this.place});
  final SportPlace place;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final sport in place.allowedSports)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(sport.icon, size: 14, color: sport.color),
                const SizedBox(width: 6),
                Text(sport.label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: onTap == null ? AppColors.outline : AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: onTap == null ? AppColors.onSurfaceMuted : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}
