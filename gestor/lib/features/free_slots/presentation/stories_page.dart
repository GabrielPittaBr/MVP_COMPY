import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/court_painter.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/common.dart';
import '../../agenda/presentation/agenda_controller.dart';
import '../../venue/data/demo_venue.dart';
import '../../venue/presentation/venue_controller.dart';
import 'free_today.dart';

/// Imagem dos horários livres para o Instagram (RF-P49, 2ª versão), com o
/// tema e as iniciais do local.
class StoriesPage extends ConsumerStatefulWidget {
  const StoriesPage({super.key});

  @override
  ConsumerState<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends ConsumerState<StoriesPage> {
  var _feed = false;

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(venueProvider);
    final groups = freeGroups(ref.watch(agendaProvider), venue, 0);
    final theme = venue.theme;
    return FormFrame(
      title: 'Divulgar no Instagram',
      actions: [
        FilledButton.icon(
          onPressed: () => showDone(
            context,
            'Na versão final, a imagem é baixada pronta para postar.',
          ),
          icon: const Icon(Icons.download),
          label: const Text('Baixar imagem'),
        ),
      ],
      children: [
        const Row(children: [LaterPill()]),
        const Text(
          'Cerca de 90% dos clientes novos chegam pelo Instagram. Poste os '
          'horários livres de hoje com o link do COMPY.',
          style: TextStyle(color: GestorColors.onSurfaceVariant),
        ),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Stories')),
            ButtonSegment(value: true, label: Text('Feed')),
          ],
          selected: {_feed},
          onSelectionChanged: (s) => setState(() => _feed = s.first),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: _feed ? 1080 / 1350 : 1080 / 1920,
              child: CourtSurface(
                style: theme.court,
                portrait: true,
                inset: 14,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Monogram(name: venue.name, size: 44),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                venue.name,
                                style: TextStyle(
                                  fontFamily: GestorTheme.display,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 20,
                                  color: theme.ink,
                                ),
                              ),
                              Text(
                                DemoVenue.city,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.ink2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'Horários livres hoje',
                        style: TextStyle(
                          fontFamily: GestorTheme.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 30,
                          height: 1,
                          color: theme.ink,
                        ),
                      ),
                      Text(
                        '${longDate(0).split(',').first.replaceAll('-feira', '')}'
                        ', ${shortDate(0).split(', ').last}',
                        style: TextStyle(fontSize: 14, color: theme.ink2),
                      ),
                      const SizedBox(height: 12),
                      for (final g in groups.take(_feed ? 3 : 5))
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                hhmm(g.hour * 60),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: GestorTheme.tabular,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  courtsLabel(g.courts),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                money(
                                  g.price ??
                                      venue.price(
                                        0,
                                        g.hour * 60,
                                        g.hour * 60 + 60,
                                      ),
                                ).replaceAll(',00', ''),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const CustomPaint(painter: _FakeQr()),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reserve pelo app',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.ink,
                                  ),
                                ),
                                Text(
                                  'Abra o COMPY e procure por ${venue.name}.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CompyBadge(color: theme.ink2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// QR de mentira, só para o desenho: o de verdade leva ao local no app.
class _FakeQr extends CustomPainter {
  const _FakeQr();

  @override
  void paint(Canvas canvas, Size size) {
    const n = 21;
    final cell = size.width / n;
    final ink = Paint()..color = GestorColors.onSurface;
    bool finder(int x, int y) {
      for (final (fx, fy) in const [(0, 0), (14, 0), (0, 14)]) {
        final dx = x - fx;
        final dy = y - fy;
        if (dx >= 0 && dx < 7 && dy >= 0 && dy < 7) {
          final ring = dx == 0 || dy == 0 || dx == 6 || dy == 6;
          final core = dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4;
          return ring || core;
        }
      }
      return ((x * 7 + y * 13 + x * y) % 5) < 2;
    }

    bool inFinderZone(int x, int y) =>
        (x < 8 && y < 8) || (x > 12 && y < 8) || (x < 8 && y > 12);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final on = inFinderZone(x, y)
            ? finder(x, y)
            : ((x * 7 + y * 13 + x * y) % 5) < 2;
        if (on) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), ink);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FakeQr old) => false;
}
