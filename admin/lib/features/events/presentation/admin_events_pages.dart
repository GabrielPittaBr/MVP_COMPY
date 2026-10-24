import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/operations/admin_operations.dart';
import '../../../core/shell/admin_shell.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_deletion_dialog.dart';
import '../../../core/widgets/admin_status_pill.dart';
import '../data/admin_events_repository.dart';
import 'admin_events_controller.dart';

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({
    this.repository,
    this.clock = DateTime.now,
    super.key,
  });

  final AdminEventsRepository? repository;

  /// Relógio da fase de cada evento; os testes fixam o instante.
  final DateTime Function() clock;

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  late final AdminEventsController _controller = AdminEventsController(
    widget.repository ?? FirebaseAdminEventsRepository(),
  )..addListener(_onChanged);
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _controller.updateFilters(const AdminEventsFilters());
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final now = widget.clock();
    // Lista vazia vinda do cache significa falta de conexão sem nada salvo,
    // não ausência de eventos.
    final offlineWithoutCache =
        state.isFromCache && state.events.isEmpty && !state.isLoading;
    return ListView(
      padding: adminPagePadding(context),
      children: <Widget>[
        Text(
          'Eventos Esportivos',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        _buildFilters(state.filters),
        if (state.isFromCache && !offlineWithoutCache) ...<Widget>[
          const SizedBox(height: 12),
          const _EventsOfflineBanner(),
        ],
        const SizedBox(height: 16),
        if (state.isLoading && state.events.isEmpty)
          const _EventsSkeleton()
        else if (state.error != null && state.events.isEmpty)
          _EventsError(onRetry: _controller.retry)
        else if (offlineWithoutCache)
          _EventsError(
            onRetry: _controller.retry,
            message: 'Sem conexão e nenhum evento salvo neste navegador.',
          )
        else if (state.events.isEmpty)
          _EventsMessage(
            icon: Icons.event_busy_outlined,
            message: state.filters == const AdminEventsFilters()
                ? 'Nenhum Evento Esportivo criado ainda.'
                : 'Nenhum evento corresponde aos filtros.',
            action: state.filters == const AdminEventsFilters()
                ? null
                : TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Limpar filtros'),
                  ),
          )
        else ...<Widget>[
          if (state.error != null)
            _EventsInlineError(onRetry: _controller.retry),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (final (index, event) in state.events.indexed) ...<Widget>[
                  if (index > 0) const Divider(),
                  AdminEventTile(
                    event: event,
                    now: now,
                    onTap: () =>
                        context.go('/events/${Uri.encodeComponent(event.id)}'),
                  ),
                ],
              ],
            ),
          ),
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.hasMore && !state.isLoadingMore)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: OutlinedButton(
                  onPressed: _controller.loadNextPage,
                  child: const Text('Carregar mais eventos'),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildFilters(AdminEventsFilters filters) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Buscar por título',
        textField: true,
        child: SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Buscar por título',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                _controller.updateFilters(
                  _controller.state.filters.copyWith(titlePrefix: value),
                );
              });
            },
          ),
        ),
      ),
      Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Filtro: Modalidade',
        child: SizedBox(
          width: 210,
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>(filters.sport ?? ''),
            initialValue: filters.sport ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Modalidade'),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem(value: '', child: Text('Todas')),
              for (final MapEntry(key: value, value: label)
                  in _sportLabels.entries)
                DropdownMenuItem(value: value, child: Text(label)),
            ],
            onChanged: (value) => _controller.updateFilters(
              filters.copyWith(
                sport: value,
                clearSport: value == null || value.isEmpty,
              ),
            ),
          ),
        ),
      ),
      TextButton.icon(
        onPressed: _clearFilters,
        icon: const Icon(Icons.clear),
        label: const Text('Limpar filtros'),
      ),
    ],
  );
}

/// Linha de um Evento Esportivo em listas: data, título, local, quem
/// organizou e vagas, com a fase em pílula.
class AdminEventTile extends StatelessWidget {
  const AdminEventTile({
    required this.event,
    required this.now,
    required this.onTap,
    this.showOrganizer = true,
    super.key,
  });

  final AdminEventRecord event;
  final DateTime now;
  final VoidCallback onTap;

  /// Desligado onde o organizador já é o assunto da página.
  final bool showOrganizer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final pill = adminEventStatusPill(event.statusAt(now));
    // Em telas estreitas a fase desce para não espremer o título.
    final compact = MediaQuery.sizeOf(context).width < 600;
    final organizer = event.organizer;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
        child: Row(
          children: <Widget>[
            _DateBadge(date: event.startsAt),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_titleOf(event), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${_sportLabel(event.sport)} · ${_placeOf(event)}',
                    style: muted,
                  ),
                  Text(
                    <String>[
                      if (showOrganizer && organizer != null)
                        'Organizado por ${_nameOf(organizer)}',
                      _spotsLabel(event),
                    ].join(' · '),
                    style: muted.copyWith(fontSize: 13),
                  ),
                  if (compact) ...<Widget>[const SizedBox(height: 8), pill],
                ],
              ),
            ),
            if (!compact) ...<Widget>[const SizedBox(width: 16), pill],
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

AdminStatusPill adminEventStatusPill(AdminEventStatus status) =>
    switch (status) {
      AdminEventStatus.scheduled => const AdminStatusPill(
        label: 'Agendado',
        tone: AdminStatusTone.info,
      ),
      AdminEventStatus.happening => const AdminStatusPill(
        label: 'Acontecendo',
        tone: AdminStatusTone.positive,
      ),
      AdminEventStatus.ended => const AdminStatusPill(
        label: 'Encerrado',
        tone: AdminStatusTone.neutral,
      ),
    };

/// Dia e mês em destaque, como numa folhinha, com o horário embaixo.
class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final local = date?.toLocal();
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: _dateTimeLabel(date),
      child: ExcludeSemantics(
        child: Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: <Widget>[
              Text(
                local == null ? '—' : _months[local.month - 1].toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
              Text(
                local == null ? '' : '${local.day}',
                style: const TextStyle(
                  fontFamily: AdminTheme.displayFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: 26,
                  height: 1.1,
                  fontFeatures: AdminTheme.tabularFigures,
                ),
              ),
              if (local != null)
                Text(
                  _timeLabel(local),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    fontFeatures: AdminTheme.tabularFigures,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminEventDetailsPage extends StatefulWidget {
  const AdminEventDetailsPage({
    required this.eventId,
    this.repository,
    this.clock = DateTime.now,
    super.key,
  });

  final String eventId;
  final AdminEventsRepository? repository;
  final DateTime Function() clock;

  @override
  State<AdminEventDetailsPage> createState() => _AdminEventDetailsPageState();
}

class _AdminEventDetailsPageState extends State<AdminEventDetailsPage> {
  late final AdminEventsRepository _repository =
      widget.repository ?? FirebaseAdminEventsRepository();
  late Future<AdminEventRecord?> _event = _repository.loadEvent(widget.eventId);

  void _retry() =>
      setState(() => _event = _repository.loadEvent(widget.eventId));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: adminPagePadding(context),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Voltar para Eventos',
              onPressed: () => context.go('/events'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Detalhes do Evento',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FutureBuilder<AdminEventRecord?>(
          future: _event,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _EventsError(
                message: 'Não foi possível carregar o evento.',
                onRetry: _retry,
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const _EventsSkeleton();
            }
            final event = snapshot.data;
            if (event == null) {
              return const _EventGone(message: 'Evento não encontrado.');
            }
            return _AdminEventDetailsContent(
              event: event,
              now: widget.clock(),
              repository: _repository,
            );
          },
        ),
      ],
    );
  }
}

const String _deletionConsequences =
    'A exclusão é definitiva. O evento some do app para todos, junto com as '
    'notificações de fim de evento dos participantes e as avaliações do '
    'próprio evento. As avaliações do local e dos participantes continuam.';

class _AdminEventDetailsContent extends StatefulWidget {
  const _AdminEventDetailsContent({
    required this.event,
    required this.now,
    required this.repository,
  });

  final AdminEventRecord event;
  final DateTime now;
  final AdminEventsRepository repository;

  @override
  State<_AdminEventDetailsContent> createState() =>
      _AdminEventDetailsContentState();
}

class _AdminEventDetailsContentState extends State<_AdminEventDetailsContent> {
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;
  bool _blocked = false;
  bool _showReasonError = false;
  String? _goneMessage;
  String? _actionError;
  String? _pendingSignature;
  String? _pendingOperationId;

  AdminEventRecord get _event => widget.event;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _requestDeletion() async {
    if (_blocked || _submitting) return;
    final reason = normalizeAdminReason(_reasonController.text);
    if (!isValidAdminReason(reason)) {
      setState(() {
        _showReasonError = true;
        _actionError = null;
      });
      return;
    }
    setState(() {
      _showReasonError = false;
      _actionError = null;
    });
    final confirmed = await confirmAdminDeletion(
      context,
      title: 'Excluir evento?',
      details: <String>[
        'Evento: ${_titleOf(_event)}',
        'ID: ${_event.id}',
        'Motivo: $reason',
      ],
      consequences: _deletionConsequences,
      confirmLabel: 'Excluir evento',
    );
    if (!mounted || !confirmed) return;
    await _executeDeletion(reason);
  }

  Future<void> _executeDeletion(String reason) async {
    final signature = '${_event.id}\u0000$reason';
    final operationId = _pendingSignature == signature
        ? _pendingOperationId!
        : newAdminOperationId();
    setState(() {
      _submitting = true;
      _actionError = null;
      _pendingSignature = signature;
      _pendingOperationId = operationId;
    });
    try {
      final result = await widget.repository.deleteEvent(
        eventId: _event.id,
        reason: reason,
        operationId: operationId,
      );
      if (result.eventId != _event.id) {
        throw const FormatException(
          'A resposta da exclusão não corresponde ao evento.',
        );
      }
      if (!mounted) return;
      setState(() => _goneMessage = 'Evento excluído.');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Evento excluído.')));
    } on Object catch (error) {
      if (!mounted) return;
      final code = error is FirebaseFunctionsException ? error.code : null;
      setState(() {
        if (code == 'not-found') _goneMessage = 'Este evento já não existe.';
        _actionError = _safeDeletionError(error);
        if (isTerminalAdminOperationFailure(error)) {
          _pendingSignature = null;
          _pendingOperationId = null;
        }
        if (code == 'permission-denied') _blocked = true;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goneMessage = _goneMessage;
    if (goneMessage != null) return _EventGone(message: goneMessage);

    final event = _event;
    final textTheme = Theme.of(context).textTheme;
    final organizer = event.organizer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(_titleOf(event), style: textTheme.headlineSmall),
                    adminEventStatusPill(event.statusAt(widget.now)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _Tag(_sportLabel(event.sport)),
                    _Tag(_skillLabel(event.skillLevel)),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailLine(
                  label: 'Início',
                  value: _dateTimeLabel(event.startsAt),
                ),
                _DetailLine(
                  label: 'Fim previsto',
                  value: _dateTimeLabel(event.endsAt),
                ),
                if (event.endedAt != null)
                  _DetailLine(
                    label: 'Encerramento',
                    value:
                        '${_dateTimeLabel(event.endedAt)}, '
                        '${event.endedAutomatically ? 'automático' : 'pelo organizador'}',
                  ),
                _DetailLine(label: 'Local', value: _placeOf(event)),
                if (event.placeAddress != null)
                  _DetailLine(label: 'Endereço', value: event.placeAddress!),
                _DetailLine(label: 'Vagas', value: _spotsLabel(event)),
                _DetailLine(
                  label: 'Avaliações enviadas',
                  value: '${event.ratedByCount}',
                ),
                _DetailLine(label: 'ID', value: event.id),
                if (event.description.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text('Descrição', style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(event.description.trim()),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text('Organizador', style: textTheme.titleLarge),
              ),
              if (organizer == null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text('Não informado'),
                )
              else
                _PersonTile(person: organizer),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  'Participantes (${event.participants.length})',
                  style: textTheme.titleLarge,
                ),
              ),
              if (event.participants.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Text('Nenhum participante.'),
                )
              else ...<Widget>[
                for (final person in event.participants)
                  _PersonTile(
                    person: person,
                    organizer: person.uid == organizer?.uid,
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildDeletionCard(context),
      ],
    );
  }

  Widget _buildDeletionCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reason = normalizeAdminReason(_reasonController.text);
    final reasonError = _showReasonError && !isValidAdminReason(reason)
        ? 'Informe um motivo com 10 a 500 caracteres após normalização.'
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Excluir evento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Text(
                _deletionConsequences,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              label: 'Motivo obrigatório',
              textField: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: TextField(
                  controller: _reasonController,
                  enabled:
                      !_submitting && !_blocked && _pendingOperationId == null,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: 'Motivo obrigatório',
                    hintText: 'Descreva o motivo da exclusão',
                    errorText: reasonError,
                  ),
                  onChanged: (_) {
                    if (_actionError != null || _showReasonError) {
                      setState(() => _actionError = null);
                    }
                  },
                ),
              ),
            ),
            if (_actionError != null) ...<Widget>[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _actionError!,
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
            if (_blocked) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'A exclusão está indisponível nesta sessão. Recarregue a página antes de tentar novamente.',
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  onPressed: _submitting || _blocked ? null : _requestDeletion,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: const Text('Excluir evento'),
                ),
                if (_submitting)
                  Semantics(
                    label: 'Exclusão em andamento',
                    liveRegion: true,
                    child: const Text('Aguardando confirmação do servidor…'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _safeDeletionError(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'not-found' => 'Este evento já não existe.',
      'permission-denied' => 'Esta sessão não pode excluir eventos.',
      'invalid-argument' => 'Revise o motivo e tente novamente.',
      'already-exists' => 'Houve um conflito na identificação da operação. Revise os dados e tente novamente.',
      _ => 'Não foi possível confirmar a exclusão. Tentar novamente repetirá a mesma solicitação com segurança.',
    };
  }
  return 'Não foi possível confirmar a exclusão. Seus dados foram preservados; tente novamente.';
}

/// Organizador ou Participante, com atalho para os detalhes do Usuário.
class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, this.organizer = false});

  final AdminEventPerson person;
  final bool organizer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.go('/users/${Uri.encodeComponent(person.uid)}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 16, 10),
        child: Row(
          children: <Widget>[
            _PersonAvatar(person: person),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_nameOf(person), style: theme.textTheme.titleSmall),
                  Text(
                    person.handle.isEmpty ? 'Sem handle' : person.handle,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (organizer) ...<Widget>[
              const _Tag('Organizador'),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.person});

  final AdminEventPerson person;

  @override
  Widget build(BuildContext context) {
    final url = Uri.tryParse(person.avatarUrl);
    final hasImage =
        url != null && url.scheme == 'https' && url.host.isNotEmpty;
    final initials = person.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.characters.first.toUpperCase())
        .take(2)
        .join();
    return CircleAvatar(
      radius: 20,
      backgroundImage: hasImage ? NetworkImage(person.avatarUrl) : null,
      child: hasImage
          ? null
          : initials.isEmpty
          ? const Icon(Icons.person_outline)
          : ExcludeSemantics(
              child: Text(
                initials,
                style: const TextStyle(
                  fontFamily: AdminTheme.displayFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }
}

/// "Rótulo: valor" num só texto selecionável, com o rótulo esmaecido.
class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SelectableText.rich(
        TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

/// Fim da página de um evento que não existe mais, excluído aqui ou antes.
class _EventGone extends StatelessWidget {
  const _EventGone({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: _EventsMessage(
      icon: Icons.event_busy_outlined,
      message: message,
      action: OutlinedButton.icon(
        onPressed: () => context.go('/events'),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Voltar para Eventos'),
      ),
    ),
  );
}

class _EventsSkeleton extends StatelessWidget {
  const _EventsSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Semantics(
      label: 'Carregando Eventos Esportivos',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            const LinearProgressIndicator(),
            for (var row = 0; row < 3; row++)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: <Widget>[
                    bar(60, 60),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        bar(220, 14),
                        const SizedBox(height: 10),
                        bar(140, 12),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mensagem de estado vazio ou de falha, com a ação que resolve.
class _EventsMessage extends StatelessWidget {
  const _EventsMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _EventsError extends StatelessWidget {
  const _EventsError({
    required this.onRetry,
    this.message = 'Não foi possível carregar os eventos.',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) => _EventsMessage(
    icon: Icons.cloud_off_outlined,
    message: message,
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Tentar novamente'),
    ),
  );
}

class _EventsInlineError extends StatelessWidget {
  const _EventsInlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Erro ao atualizar. Tentar novamente'),
    ),
  );
}

class _EventsOfflineBanner extends StatelessWidget {
  const _EventsOfflineBanner();

  @override
  Widget build(BuildContext context) => const Material(
    color: AdminColors.warningContainer,
    borderRadius: BorderRadius.all(Radius.circular(10)),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off_outlined, color: AdminColors.onWarningContainer),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Exibindo dados em cache; conecte-se para ver atualizações.',
              style: TextStyle(color: AdminColors.onWarningContainer),
            ),
          ),
        ],
      ),
    ),
  );
}

const Map<String, String> _sportLabels = <String, String>{
  'futebol': 'Futebol',
  'basquete': 'Basquete',
  'volei': 'Vôlei',
  'tenisDeMesa': 'Tênis de mesa',
  'futsal': 'Futsal',
  'corrida': 'Corrida',
  'ciclismo': 'Ciclismo',
  'caminhada': 'Caminhada',
};

String _sportLabel(String sport) =>
    _sportLabels[sport] ?? (sport.isEmpty ? 'Modalidade não informada' : sport);

String _skillLabel(String level) => switch (level) {
  'iniciante' => 'Iniciante',
  'intermediario' => 'Intermediário',
  'avancado' => 'Avançado',
  _ => 'Todos os níveis',
};

String _titleOf(AdminEventRecord event) =>
    event.title.trim().isEmpty ? 'Sem título' : event.title.trim();

String _nameOf(AdminEventPerson person) =>
    person.name.trim().isEmpty ? 'Sem nome' : person.name.trim();

String _placeOf(AdminEventRecord event) {
  final place = event.placeName ?? event.location;
  return place.trim().isEmpty ? 'Local não informado' : place.trim();
}

String _spotsLabel(AdminEventRecord event) {
  // Documento malformado não pode virar vaga negativa nem estourar o clamp.
  final total = event.totalSpots < 0 ? 0 : event.totalSpots;
  final filled = (total - event.remainingSpots).clamp(0, total);
  return '$filled de $total vagas preenchidas';
}

const List<String> _months = <String>[
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String _two(int value) => value.toString().padLeft(2, '0');

String _timeLabel(DateTime local) =>
    '${_two(local.hour)}:${_two(local.minute)}';

String _dateTimeLabel(DateTime? date) {
  if (date == null) return 'Não informado';
  final local = date.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} às '
      '${_timeLabel(local)}';
}
