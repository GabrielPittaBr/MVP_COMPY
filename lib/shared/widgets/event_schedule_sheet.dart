import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/duration_format.dart';
import '../models/event.dart';

/// Consulta local, sem inscrição, navegação para detalhes ou leitura extra.
Future<void> showEventScheduleSheet(BuildContext context, Event event) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _EventScheduleSheet(event: event),
  );
}

class _EventScheduleSheet extends StatelessWidget {
  const _EventScheduleSheet({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    // Datas do Firestore já chegam locais. toLocal também cobre eventos
    // fornecidos em UTC, sem reinterpretar strings ou fixar um fuso.
    final start = event.dateTime.toLocal();
    final end = event.endsAt.toLocal();
    final dateFormat = DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR');
    final timeFormat = DateFormat('HH:mm', 'pt_BR');
    final date = dateFormat.format(start);
    final endOnSameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              const Expanded(
                  child: Text(
                AppStrings.eventDateTimeTitle,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              )),
              IconButton(
                tooltip: AppStrings.commonClose,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${date[0].toUpperCase()}${date.substring(1)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text('${AppStrings.eventStart}: ${timeFormat.format(start)}'),
            const SizedBox(height: 8),
            Text('${AppStrings.eventExpectedEnd}: ${timeFormat.format(end)}'),
            if (!endOnSameDay) ...<Widget>[
              const SizedBox(height: 4),
              Text(dateFormat.format(end),
                  style: const TextStyle(color: AppColors.onSurfaceMuted)),
            ],
            const SizedBox(height: 8),
            Text(
                '${AppStrings.eventDuration}: ${DurationFormat.short(event.durationMinutes)}'),
          ],
        ),
      ),
    );
  }
}
