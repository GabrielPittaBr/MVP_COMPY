import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/repositories/events_repository.dart';
import '../providers/events_providers.dart';
import '../widgets/participants_avatars.dart';

/// Tela "3.1 Evento detalhes": cabeçalho com banner, dados,
/// criador, descrição, participantes e mapa do local.
///
/// RN-05: o botão "Participar" é desabilitado quando `event.isFull`.
class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      body: detailAsync.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Evento não encontrado.'));
          }
          return _Body(event: event);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('EEEE, h:mm a', 'pt_BR');

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.onSurface,
          elevation: 0,
          title: Text(event.title),
          leading: const BackButton(),
        ),
        SliverToBoxAdapter(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: event.bannerUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: AppColors.surfaceMuted,
                alignment: Alignment.center,
                child: Icon(event.sport.icon, size: 60, color: event.sport.color),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              Text(
                'Partida de ${event.sport.label.toLowerCase()}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _IconRow(
                icon: event.sport.icon,
                iconColor: event.sport.color,
                label: event.sport.label,
              ),
              const SizedBox(height: 8),
              _IconRow(
                icon: Icons.calendar_today_outlined,
                label: _capitalize(dateFormat.format(event.dateTime)),
              ),
              const SizedBox(height: 20),

              const Text(
                AppStrings.eventCreatedBy,
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _CreatorTile(event: event),
              const SizedBox(height: 20),

              // Descrição é opcional: sem texto, o bloco inteiro some
              // (nada de espaçamento órfão no meio do layout).
              if (event.description.isNotEmpty) ...<Widget>[
                const Text(
                  AppStrings.eventDescription,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(event.description, style: const TextStyle(height: 1.45)),
                const SizedBox(height: 24),
              ],

              Text(
                'Participantes (${event.participants.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ParticipantsAvatars(participants: event.participants),
              const SizedBox(height: 24),

              const Text(
                AppStrings.eventLocation,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 160,
                  child: AbsorbPointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: event.coordinates,
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'br.com.compy.mvp',
                        ),
                        MarkerLayer(
                          markers: <Marker>[
                            Marker(
                              point: event.coordinates,
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.error,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                label: event.isFull ? AppStrings.eventFull : AppStrings.eventJoin,
                onPressed: event.isFull ? null : () => _join(context, ref),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // UserSummary real do usuário autenticado (users/{uid} no Firestore).
      final user = await ref.read(currentUserSummaryProvider.future);
      await ref.read(joinEventProvider).call(event.id, user);
      // Re-emite o evento atualizado.
      ref.invalidate(eventDetailProvider(event.id));
      ref.invalidate(paginatedEventsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Você entrou no evento!')),
      );
    } on EventFullException {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.eventFull)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao entrar no evento: $e')),
      );
    }
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.icon,
    required this.label,
    this.iconColor = AppColors.onSurface,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: iconColor),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _CreatorTile extends StatelessWidget {
  const _CreatorTile({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundImage: CachedNetworkImageProvider(event.creator.avatarUrl),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.creator.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  event.creator.handle,
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
