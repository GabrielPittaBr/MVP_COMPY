import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/admin_colors.dart';
import '../data/admin_reports_repository.dart';

/// Fila de denúncias (chore/lgpd; Play, conteúdo gerado por usuário; ECA
/// Digital, arts. 28–30).
///
/// As denúncias que envolvem criança ou adolescente vêm primeiro. A ação em
/// si (suspender, excluir a conta ou o evento) é feita nas telas de Usuários
/// e Eventos, que já registram o motivo em `adminOperations`; aqui a
/// denúncia é só fechada, com uma nota do que foi feito.
class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({this.repository, super.key});

  final AdminReportsRepository? repository;

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  late final AdminReportsRepository _repository =
      widget.repository ?? FirestoreAdminReportsRepository();
  bool _showClosed = false;
  late Future<List<AdminReport>> _reports = _load();

  Future<List<AdminReport>> _load() =>
      _showClosed ? _repository.listClosed() : _repository.listOpen();

  void _reload() => setState(() => _reports = _load());

  Future<void> _close(AdminReport report, {required bool resolved}) async {
    final String? note = await showDialog<String>(
      context: context,
      builder: (_) => _CloseReportDialog(resolved: resolved),
    );
    if (note == null || !mounted) return;
    try {
      await _repository.close(report.id, resolved: resolved, resolution: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resolved ? 'Denúncia resolvida.' : 'Denúncia descartada.')),
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível fechar a denúncia.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Text('Denúncias', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Os administradores não leem conversas: em denúncias de mensagem, o '
          'texto abaixo é a cópia conferida da mensagem denunciada. Para agir, '
          'abra o usuário ou o evento e use suspender ou excluir.',
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: false, label: Text('Abertas')),
            ButtonSegment<bool>(value: true, label: Text('Fechadas')),
          ],
          selected: <bool>{_showClosed},
          onSelectionChanged: (Set<bool> value) {
            _showClosed = value.first;
            _reload();
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<AdminReport>>(
          future: _reports,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Column(
                children: <Widget>[
                  const Text('Não foi possível carregar as denúncias.'),
                  TextButton(onPressed: _reload, child: const Text('Tentar de novo')),
                ],
              );
            }
            final List<AdminReport> reports = snapshot.data ?? const <AdminReport>[];
            if (reports.isEmpty) {
              return Text(_showClosed ? 'Nenhuma denúncia fechada.' : 'Nenhuma denúncia aberta.');
            }
            return Column(
              children: <Widget>[
                for (final AdminReport report in reports)
                  _ReportCard(
                    report: report,
                    onResolve: () => _close(report, resolved: true),
                    onDismiss: () => _close(report, resolved: false),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onResolve, required this.onDismiss});

  final AdminReport report;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;

  String _date(DateTime? date) {
    if (date == null) return '—';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool urgent = report.priority == 0;
    final String targetLabel = switch (report.target) {
      AdminReportTarget.user => 'Perfil',
      AdminReportTarget.event => 'Evento',
      AdminReportTarget.message => 'Mensagem',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: urgent ? AdminColors.error : Colors.transparent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (urgent)
                  const Chip(
                    avatar: Icon(Icons.priority_high, size: 16),
                    label: Text('Prioridade: criança ou adolescente'),
                  ),
                Chip(label: Text(targetLabel)),
                Text(report.reasonLabel, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('Recebida em ${_date(report.createdAt)}'),
            if (report.details.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('Relato: ${report.details}'),
            ],
            if (report.messageText != null) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('“${report.messageText}”'),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => context.go('/users/${Uri.encodeComponent(report.targetUid)}'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Abrir denunciado'),
                ),
                if (report.target == AdminReportTarget.event)
                  OutlinedButton.icon(
                    onPressed: () => context.go('/events/${Uri.encodeComponent(report.targetId)}'),
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('Abrir evento'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/users/${Uri.encodeComponent(report.reporterId)}'),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Abrir quem denunciou'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (report.isOpen)
              Wrap(
                spacing: 8,
                children: <Widget>[
                  FilledButton(onPressed: onResolve, child: const Text('Resolver')),
                  TextButton(onPressed: onDismiss, child: const Text('Descartar')),
                ],
              )
            else
              Text(
                '${report.status == 'resolved' ? 'Resolvida' : 'Descartada'} em '
                '${_date(report.resolvedAt)}'
                '${(report.resolution ?? '').isEmpty ? '' : ': ${report.resolution}'}',
              ),
          ],
        ),
      ),
    );
  }
}

class _CloseReportDialog extends StatefulWidget {
  const _CloseReportDialog({required this.resolved});

  final bool resolved;

  @override
  State<_CloseReportDialog> createState() => _CloseReportDialogState();
}

class _CloseReportDialogState extends State<_CloseReportDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.resolved ? 'Resolver denúncia' : 'Descartar denúncia'),
      content: TextField(
        controller: _note,
        maxLength: 500,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: widget.resolved
              ? 'O que foi feito (ex.: conta suspensa)'
              : 'Por que não procede',
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_note.text),
          child: Text(widget.resolved ? 'Resolver' : 'Descartar'),
        ),
      ],
    );
  }
}
