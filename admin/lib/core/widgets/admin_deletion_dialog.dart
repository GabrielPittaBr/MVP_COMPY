import 'package:flutter/material.dart';

/// Confirmação das exclusões definitivas do painel.
///
/// Mostra o alvo e o motivo, explica o que some e o que fica, e só libera o
/// botão depois de a pessoa marcar que a exclusão não pode ser desfeita.
Future<bool> confirmAdminDeletion(
  BuildContext context, {
  required String title,
  required List<String> details,
  required String consequences,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _AdminDeletionDialog(
      title: title,
      details: details,
      consequences: consequences,
      confirmLabel: confirmLabel,
    ),
  );
  return confirmed == true;
}

class _AdminDeletionDialog extends StatefulWidget {
  const _AdminDeletionDialog({
    required this.title,
    required this.details,
    required this.consequences,
    required this.confirmLabel,
  });

  final String title;
  final List<String> details;
  final String consequences;
  final String confirmLabel;

  @override
  State<_AdminDeletionDialog> createState() => _AdminDeletionDialogState();
}

class _AdminDeletionDialogState extends State<_AdminDeletionDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final detail in widget.details) ...<Widget>[
                SelectableText(detail),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              Text(widget.consequences),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _acknowledged,
                onChanged: (value) =>
                    setState(() => _acknowledged = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Entendo que a exclusão é definitiva e não pode ser desfeita.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: _acknowledged
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
