import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/presentation/notification_bell.dart';
import '../../features/venue/presentation/venue_controller.dart';
import '../layout.dart';
import '../theme/court_painter.dart';
import '../theme/gestor_colors.dart';
import '../theme/gestor_theme.dart';
import '../widgets/common.dart';

/// Página do painel. No celular, o cabeçalho tem a quadra do tema; no
/// computador, o título fica no topo do conteúdo, com as ações ao lado.
class PageScaffold extends ConsumerWidget {
  const PageScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.mobileTitle,
    this.mobileSubtitle,
    this.actions = const [],
    this.back,
    this.bell = false,
    this.gap = 20,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? mobileTitle;
  final String? mobileSubtitle;

  /// Ações do cabeçalho no computador. No celular, cada página põe as suas
  /// no conteúdo, ao alcance do polegar.
  final List<Widget> actions;

  /// Rota de volta, para as páginas abertas pelo "Mais" no celular.
  final String? back;
  final bool bell;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaced = [
      for (final (i, child) in children.indexed) ...[
        if (i > 0) SizedBox(height: gap),
        child,
      ],
    ];
    if (isDesktop(context)) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(40, 36, 40, 48),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: GestorColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (bell)
                    const NotificationBell(color: GestorColors.onSurface),
                  ...actions,
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...spaced,
        ],
      );
    }
    return Column(
      children: [
        VenueHeader(
          title: mobileTitle ?? title,
          subtitle: mobileSubtitle ?? subtitle,
          back: back,
          bell: bell,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: spaced,
          ),
        ),
      ],
    );
  }
}

/// Cabeçalho do celular, sobre a quadra do tema do local.
class VenueHeader extends ConsumerWidget {
  const VenueHeader({
    required this.title,
    this.subtitle,
    this.back,
    this.bell = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? back;
  final bool bell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueProvider);
    final theme = venue.theme;
    final top = MediaQuery.paddingOf(context).top;
    return CourtSurface(
      style: theme.court,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: SizedBox(
          height: 112,
          child: Padding(
            padding: EdgeInsets.only(left: back == null ? 24 : 8, right: 12),
            child: Row(
              children: [
                if (back == null)
                  Monogram(name: venue.name)
                else
                  IconButton(
                    tooltip: 'Voltar',
                    onPressed: () => context.go(back!),
                    icon: Icon(Icons.arrow_back, color: theme.ink),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GestorTheme.display,
                          fontWeight: FontWeight.w600,
                          fontSize: 26,
                          height: 1.05,
                          color: theme.ink,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: theme.ink2),
                        ),
                      ],
                    ],
                  ),
                ),
                if (bell) NotificationBell(color: theme.ink, ring: theme.floor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Moldura dos formulários: painel ao lado da agenda no computador e tela
/// cheia no celular, com o botão principal sempre à vista.
class FormFrame extends ConsumerWidget {
  const FormFrame({
    required this.title,
    required this.children,
    this.actions = const [],
    super.key,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inPanel = PanelScope.of(context);
    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        inPanel ? 24 : 16,
        inPanel ? 20 : 16,
        inPanel ? 24 : 16,
        24,
      ),
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 18),
          child,
        ],
      ],
    );
    final footer = actions.isEmpty
        ? null
        : DecoratedBox(
            decoration: const BoxDecoration(
              color: GestorColors.surface,
              border: Border(
                top: BorderSide(color: GestorColors.outlineVariant),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: inPanel ? 24 : 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    for (final (i, action) in actions.indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: action),
                    ],
                  ],
                ),
              ),
            ),
          );
    if (inPanel) {
      return Material(
        color: GestorColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => closeForm(context, ref),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(child: body),
            ?footer,
          ],
        ),
      );
    }
    final theme = ref.watch(venueProvider.select((v) => v.theme));
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: GestorColors.background,
      body: Column(
        children: [
          CourtSurface(
            style: theme.court,
            inset: 8,
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => closeForm(context, ref),
                      icon: Icon(Icons.close, color: theme.ink),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GestorTheme.display,
                          fontWeight: FontWeight.w600,
                          fontSize: 24,
                          color: theme.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: footer,
    );
  }
}
