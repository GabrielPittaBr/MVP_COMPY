import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/report.dart';
import '../providers/safety_providers.dart';

/// Abre a folha de denúncia de [target] e avisa o resultado num SnackBar.
Future<void> showReportSheet(BuildContext context, WidgetRef ref, ReportTarget target) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final bool? sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(target: target),
  );
  if (sent == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(sent ? AppStrings.reportSent : AppStrings.reportError),
      backgroundColor: sent ? null : AppColors.error,
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.target});

  final ReportTarget target;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final TextEditingController _details = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ReportReason? reason = _reason;
    if (reason == null || _sending) return;
    setState(() => _sending = true);
    final bool sent = await ref.read(safetyActionsProvider).report(widget.target, reason, _details.text);
    if (mounted) Navigator.of(context).pop(sent);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(widget.target.title, style: text.titleLarge),
              const SizedBox(height: 4),
              Text(AppStrings.reportReasonLabel, style: text.bodyMedium),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (ReportReason? value) => setState(() => _reason = value),
                child: Column(
                  children: <Widget>[
                    for (final ReportReason reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        title: Text(reason.label),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              if (_reason == ReportReason.childSafety)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    AppStrings.reportEmergencyNote,
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                  ),
                ),
              TextField(
                controller: _details,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(hintText: AppStrings.reportDetailsHint),
              ),
              Text(
                AppStrings.reportPrivacyNote,
                style: text.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _reason == null || _sending ? null : _send,
                child: Text(_sending ? AppStrings.authLoading : AppStrings.reportSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
