import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/events/domain/entities/events_filter.dart';
import '../../../../features/events/presentation/providers/events_providers.dart';
import '../../../../features/events/presentation/widgets/events_filter_sheet.dart';
import '../../../../shared/widgets/event_card.dart';
import '../providers/home_providers.dart';
import '../widgets/category_circle.dart';
import '../widgets/explore_map_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/search_field.dart';

/// Tela inicial (RF07 + RF11): saudação, busca, categorias, mapa preview e
/// listagem de eventos próximos.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(greetingNameProvider);
    final categories = ref.watch(categoriesProvider);
    final eventsAsync = ref.watch(nearbyEventsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GreetingHeader(
                userName: userName,
                // `go`, e não `push`: o avatar troca de aba. Mesmo caminho do
                // carrossel de categorias logo abaixo, que leva a Eventos.
                onAvatarTap: () => context.go(AppRoutes.profile),
                onSettingsTap: () => context.push(AppRoutes.settings),
              ),
              const SizedBox(height: 16),
              const SearchField(),
              const SizedBox(height: 24),

              const _SectionTitle(AppStrings.homeCategories),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  // +1 para o "Ver mais" no fim da fileira.
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) {
                    if (i == categories.length) {
                      return MoreCategoriesCircle(
                        onTap: () => showEventsFilterSheet(
                          context,
                          navigateToEventsOnApply: true,
                        ),
                      );
                    }
                    return CategoryCircle(
                      category: categories[i],
                      // Seta o filtro antes de trocar de aba: o
                      // PaginatedEventsController observa esse provider e
                      // já reconstrói a lista filtrada.
                      onTap: () {
                        ref.read(eventsFilterProvider.notifier).state =
                            const EventsFilter().withSport(categories[i].sport);
                        context.go(AppRoutes.events);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              const _SectionTitle(AppStrings.homeExplore),
              const SizedBox(height: 12),
              ExploreMapCard(onTap: () => context.go(AppRoutes.maps)),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const _SectionTitle(AppStrings.homeNearbyEvents),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.onSurfaceMuted,
                    ),
                    label: const Text(
                      AppStrings.homeFilterByDate,
                      style: TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              eventsAsync.when(
                data: (events) => Column(
                  children: <Widget>[
                    for (final e in events)
                      EventCard(
                        event: e,
                        actionLabel: AppStrings.eventJoin,
                        onAction: () => context.go('${AppRoutes.events}/${e.id}'),
                      ),
                  ],
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Não foi possível carregar eventos: $e'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    );
  }
}
