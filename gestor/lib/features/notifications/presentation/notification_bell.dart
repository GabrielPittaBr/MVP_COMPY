import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../agenda/presentation/agenda_controller.dart';
import '../../agenda/presentation/request_page.dart';
import '../../auth/presentation/session_controller.dart';

/// Sino com o número de solicitações esperando resposta (RF-P80).
class NotificationBell extends ConsumerWidget {
  const NotificationBell({
    required this.color,
    this.ring = GestorColors.background,
    super.key,
  });

  final Color color;

  /// Cor em volta do número, a do fundo onde o sino está.
  final Color ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(agendaProvider.select((s) => s.requests.length));
    return Semantics(
      button: true,
      label: count == 0
          ? 'Notificações'
          : 'Notificações: $count ${count == 1 ? 'nova' : 'novas'}',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              onPressed: () =>
                  openForm(context, ref, const NotificationsPage()),
              icon: Icon(Icons.notifications_outlined, color: color),
            ),
            if (count > 0)
              Positioned(
                top: 5,
                right: 4,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: GestorColors.error,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: ring, width: 2),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(agendaProvider.select((s) => s.requests));
    final owner = ref.watch(sessionProvider)?.role.managesVenue ?? false;
    return FormFrame(
      title: 'Notificações',
      children: [
        if (requests.isNotEmpty) ...[
          const Text(
            'Esperando resposta',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          for (final r in requests)
            _Notice(
              icon: Icons.person_add_alt_1_outlined,
              color: GestorColors.warning,
              title: '${r.title} pediu a Quadra ${r.court}',
              detail:
                  '${friendlyDate(r.day)}, ${timeRange(r.start, r.end)} · '
                  'vence em ${r.expiresIn} min',
              onTap: () => replaceForm(context, ref, RequestPage(id: r.id)),
            ),
        ],
        const Text(
          'Antes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const _Notice(
          icon: Icons.sell_outlined,
          color: GestorColors.secondary,
          title: 'Rafa reservou um horário livre',
          detail: 'Quadra 4, hoje, 18:00 às 19:00 · há 2 h',
        ),
        const _Notice(
          icon: Icons.check_circle_outline,
          color: GestorColors.primary,
          title: 'Gabi reservou pelo COMPY',
          detail: 'Quadra 5, hoje, 20:00 às 21:00 · há 3 h',
        ),
        if (owner)
          const _Notice(
            icon: Icons.workspace_premium_outlined,
            color: GestorColors.onSurfaceVariant,
            title: 'Período gratuito do Pro até 30/04/2027',
            detail: 'Avisamos de novo 15 dias antes',
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(detail),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    ),
  );
}
