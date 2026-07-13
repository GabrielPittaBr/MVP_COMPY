import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/event_card.dart';
import '../providers/search_providers.dart';

/// Tela de busca de eventos por nome ou modalidade esportiva.
///
/// Aberta pelo [SearchField] da Home. O campo alimenta o
/// `searchQueryProvider`; os resultados chegam com debounce de 500ms via
/// `searchResultsProvider`.
class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: AppStrings.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (value) =>
              ref.read(searchQueryProvider.notifier).state = value,
        ),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.search, color: AppColors.onSurfaceMuted),
          ),
        ],
      ),
      body: query.trim().length < 2
          ? const _CenteredHint(AppStrings.searchPrompt)
          : resultsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return const _CenteredHint(AppStrings.searchNoResults);
                }
                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = events[i];
                    return EventCard(
                      event: e,
                      actionLabel: AppStrings.eventSeeMore,
                      onAction: () => context.go('${AppRoutes.events}/${e.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _CenteredHint('Erro na busca: $e'),
            ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.onSurfaceMuted),
        ),
      ),
    );
  }
}
