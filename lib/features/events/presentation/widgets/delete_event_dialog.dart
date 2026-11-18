import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../../domain/usecases/delete_own_event.dart';
import '../providers/events_providers.dart';

/// Exclusão pelo Organizador (#37), no detalhe e na tela ao vivo: pergunta
/// "Excluir evento?" com o motivo opcional, exclui e leva à aba Eventos.
///
/// A exclusão roda com o diálogo aberto. Se falhar (sem conexão, por
/// exemplo), o aviso aparece nele e o motivo digitado continua lá.
///
/// [context] e [ref] têm de ser da página, e não do conteúdo dela: quando o
/// documento some, o detalhe troca o conteúdo por "Evento não encontrado",
/// às vezes antes de a callable responder.
Future<void> confirmAndDeleteOwnEvent(
  BuildContext context,
  WidgetRef ref,
  Event event,
) async {
  final deleted = await showDialog<bool>(
    context: context,
    builder: (_) => _DeleteEventDialog(
      onDelete: (reason) =>
          ref.read(deleteOwnEventProvider).call(event.id, reason: reason),
    ),
  );
  if (deleted != true || !context.mounted) return;
  invalidateEventLists(ref);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(AppStrings.eventDeleted)),
  );
  context.go(AppRoutes.events);
}

class _DeleteEventDialog extends StatefulWidget {
  const _DeleteEventDialog({required this.onDelete});

  final Future<void> Function(String reason) onDelete;

  @override
  State<_DeleteEventDialog> createState() => _DeleteEventDialogState();
}

class _DeleteEventDialogState extends State<_DeleteEventDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.onDelete(_reason.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = switch (error) {
          EventDeletionOfflineException() => AppStrings.eventDeleteOffline,
          EventAlreadyEndedException() => AppStrings.eventAlreadyEndedError,
          _ => AppStrings.eventDeleteError,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        title: const Text(AppStrings.eventDeleteConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(AppStrings.eventDeleteConfirmBody),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              enabled: !_deleting,
              maxLength: kEventDeletionReasonMaxLength,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: AppStrings.eventDeleteReasonLabel,
              ),
            ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            if (_deleting) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.commonCancel),
          ),
          TextButton(
            onPressed: _deleting ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(AppStrings.eventDeleteConfirm),
          ),
        ],
      ),
    );
  }
}
