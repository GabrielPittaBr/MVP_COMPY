import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/operations/admin_operations.dart';
import '../../../core/shell/admin_shell.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_deletion_dialog.dart';
import '../../../core/widgets/admin_status_pill.dart';
import '../../events/data/admin_events_repository.dart';
import '../../events/presentation/admin_events_pages.dart';
import '../data/admin_users_repository.dart';
import 'admin_users_controller.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({this.repository, super.key});

  final AdminUsersRepository? repository;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late final AdminUsersRepository _repository =
      widget.repository ?? FirebaseAdminUsersRepository();
  late final AdminUsersController _controller = AdminUsersController(
    _repository,
  )..addListener(_onChanged);
  final TextEditingController _queryController = TextEditingController();
  AdminUserSearchType _selectedType = AdminUserSearchType.name;

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
    _queryController.dispose();
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final result = await _controller.search(
      _selectedType,
      _queryController.text,
    );
    if (!mounted || result == null) return;
    context.go('/users/${Uri.encodeComponent(result.uid)}', extra: result);
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final isExact =
        _selectedType == AdminUserSearchType.uid ||
        _selectedType == AdminUserSearchType.email;
    return ListView(
      padding: adminPagePadding(context),
      children: <Widget>[
        Text('Usuários', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Semantics(
              container: true,
              explicitChildNodes: true,
              label: 'Tipo de pesquisa',
              child: SizedBox(
                width: 190,
                child: DropdownButtonFormField<AdminUserSearchType>(
                  key: ValueKey<AdminUserSearchType>(_selectedType),
                  initialValue: _selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pesquisar por'),
                  items: const <DropdownMenuItem<AdminUserSearchType>>[
                    DropdownMenuItem(
                      value: AdminUserSearchType.name,
                      child: Text('Nome'),
                    ),
                    DropdownMenuItem(
                      value: AdminUserSearchType.handle,
                      child: Text('Handle'),
                    ),
                    DropdownMenuItem(
                      value: AdminUserSearchType.uid,
                      child: Text('UID'),
                    ),
                    DropdownMenuItem(
                      value: AdminUserSearchType.email,
                      child: Text('E-mail'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedType = value);
                  },
                ),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              label: _selectedType == AdminUserSearchType.email
                  ? 'Consultar e-mail exato'
                  : _selectedType == AdminUserSearchType.uid
                  ? 'Consultar UID exato'
                  : 'Buscar prefixo de ${_selectedType == AdminUserSearchType.name ? 'nome' : 'handle'}',
              textField: true,
              child: SizedBox(
                width: 320,
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    labelText: switch (_selectedType) {
                      AdminUserSearchType.name => 'Nome (prefixo)',
                      AdminUserSearchType.handle => 'Handle (prefixo)',
                      AdminUserSearchType.uid => 'UID exato',
                      AdminUserSearchType.email => 'E-mail exato',
                    },
                    hintText: _selectedType == AdminUserSearchType.handle
                        ? '@maria'
                        : null,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  keyboardType: _selectedType == AdminUserSearchType.email
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: state.isLoading ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.isFromCache) const _UserOfflineBanner(),
        if (state.isLoading && state.items.isEmpty)
          const _UsersSkeleton()
        else if (state.error != null && state.items.isEmpty)
          _UsersError(onRetry: _controller.retry)
        else if (state.items.isEmpty)
          _UsersEmpty(
            exact: isExact,
            notFound: state.exactNotFound,
            query: _queryController.text,
            onClear: _queryController.text.isEmpty
                ? null
                : () {
                    _queryController.clear();
                    _selectedType = AdminUserSearchType.name;
                    setState(() {});
                    _controller.search(AdminUserSearchType.name, '');
                  },
          )
        else ...<Widget>[
          if (state.error != null)
            _UsersInlineError(onRetry: _controller.retry),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (final (index, item) in state.items.indexed) ...<Widget>[
                  if (index > 0) const Divider(),
                  _AdminUserTile(
                    item: item,
                    onTap: () => context.go(
                      '/users/${Uri.encodeComponent(item.profile.uid)}',
                    ),
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
                  child: const Text('Carregar mais usuários'),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class AdminUserDetailsPage extends StatefulWidget {
  const AdminUserDetailsPage({
    required this.uid,
    this.repository,
    this.eventsRepository,
    this.initialDetails,
    super.key,
  });

  final String uid;
  final AdminUsersRepository? repository;

  /// Fonte da seção "Eventos organizados"; sem ela, a seção não aparece.
  final AdminEventsRepository? eventsRepository;
  final AdminUserDetailsResult? initialDetails;

  @override
  State<AdminUserDetailsPage> createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends State<AdminUserDetailsPage> {
  late final AdminUsersRepository _repository =
      widget.repository ?? FirebaseAdminUsersRepository();
  late Future<AdminUserDetailsResult> _details = _load();

  Future<AdminUserDetailsResult> _load() => widget.initialDetails != null
      ? Future<AdminUserDetailsResult>.value(widget.initialDetails)
      : _repository.loadDetails(widget.uid);

  void _retry() =>
      setState(() => _details = _repository.loadDetails(widget.uid));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: adminPagePadding(context),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Voltar para Usuários',
              onPressed: () => context.go('/users'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Detalhes do Usuário',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FutureBuilder<AdminUserDetailsResult>(
          future: _details,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _UsersError(
                message: 'Não foi possível carregar os detalhes do usuário.',
                onRetry: _retry,
              );
            }
            if (!snapshot.hasData) return const _UsersSkeleton();
            return _AdminUserDetailsContent(
              result: snapshot.data!,
              repository: _repository,
              eventsRepository: widget.eventsRepository,
            );
          },
        ),
      ],
    );
  }
}

class _AdminUserDetailsContent extends StatefulWidget {
  const _AdminUserDetailsContent({
    required this.result,
    required this.repository,
    required this.eventsRepository,
  });

  final AdminUserDetailsResult result;
  final AdminUsersRepository repository;
  final AdminEventsRepository? eventsRepository;

  @override
  State<_AdminUserDetailsContent> createState() =>
      _AdminUserDetailsContentState();
}

class _AdminUserDetailsContentState extends State<_AdminUserDetailsContent> {
  late AdminUserDetailsResult _result = widget.result;
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;
  bool _actionsBlocked = false;
  bool _showReasonError = false;
  String? _actionError;
  String? _pendingSignature;
  String? _pendingOperationId;

  /// A operação em andamento é a exclusão, e não a suspensão.
  bool _deleting = false;

  /// Preenchido quando a conta deixa de existir: excluída aqui ou antes.
  String? _goneMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _requestDeletion() async {
    if (_actionsBlocked || _submitting) return;
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
    final profile = _result.profile;
    final confirmed = await confirmAdminDeletion(
      context,
      title: 'Excluir conta?',
      details: <String>[
        if (profile != null)
          'Usuário: ${profile.name.isEmpty ? 'Sem nome' : profile.name} '
              '(${profile.handle.isEmpty ? 'sem handle' : profile.handle})',
        'UID: ${_result.uid}',
        'Motivo: $reason',
      ],
      consequences: _accountDeletionConsequences,
      confirmLabel: 'Excluir conta',
    );
    if (!mounted || !confirmed) return;
    await _executeDeletion(reason);
  }

  Future<void> _executeDeletion(String reason) async {
    final signature = '${_result.uid}\u0000delete\u0000$reason';
    final operationId = _pendingSignature == signature
        ? _pendingOperationId!
        : newAdminOperationId();
    setState(() {
      _submitting = true;
      _deleting = true;
      _actionError = null;
      _pendingSignature = signature;
      _pendingOperationId = operationId;
    });
    try {
      final response = await widget.repository.deleteUserAccount(
        uid: _result.uid,
        reason: reason,
        operationId: operationId,
      );
      if (response.uid != _result.uid) {
        throw const FormatException(
          'A resposta da exclusão não corresponde à conta.',
        );
      }
      if (!mounted) return;
      setState(() => _goneMessage = 'Conta excluída.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Conta excluída.')));
    } on Object catch (error) {
      if (!mounted) return;
      final code = error is FirebaseFunctionsException ? error.code : null;
      setState(() {
        if (code == 'not-found') {
          _goneMessage = 'A conta e o perfil já não existem.';
        }
        _actionError = _safeDeletionError(error);
        if (isTerminalAdminOperationFailure(error)) {
          _pendingSignature = null;
          _pendingOperationId = null;
        }
        if (code == 'permission-denied' || code == 'failed-precondition') {
          _actionsBlocked = true;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _deleting = false;
        });
      }
    }
  }

  Future<void> _requestAction(AdminUserSuspensionAction action) async {
    if (_actionsBlocked || _submitting) return;
    final reason = normalizeAdminSuspensionReason(_reasonController.text);
    if (reason.length < 10 || reason.length > 500) {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == AdminUserSuspensionAction.suspend
              ? 'Confirmar suspensão'
              : 'Confirmar reativação',
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SelectableText('UID: ${_result.uid}'),
              const SizedBox(height: 12),
              Text('Motivo: $reason'),
              const SizedBox(height: 12),
              Text(
                action == AdminUserSuspensionAction.suspend
                    ? 'Novos logins e renovações de sessão serão impedidos após a operação. Um ID token já emitido ainda pode ser aceito até expirar; esta ação não é um bloqueio instantâneo de todas as sessões.'
                    : 'A conta poderá fazer login novamente. Tokens de sessões anteriores não serão restaurados.',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: action == AdminUserSuspensionAction.suspend
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              action == AdminUserSuspensionAction.suspend
                  ? 'Confirmar suspensão'
                  : 'Confirmar reativação',
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _executeAction(action, reason);
  }

  Future<void> _executeAction(
    AdminUserSuspensionAction action,
    String reason,
  ) async {
    final signature = '${_result.uid}\u0000${action.name}\u0000$reason';
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
      final response = await widget.repository.setUserSuspension(
        uid: _result.uid,
        action: action,
        reason: reason,
        operationId: operationId,
      );
      final desiredDisabled = action == AdminUserSuspensionAction.suspend;
      if (response.uid != _result.uid ||
          response.action != action ||
          response.disabled != desiredDisabled) {
        throw const FormatException(
          'A resposta da operação não corresponde à ação solicitada.',
        );
      }
      final auth = _result.auth!;
      setState(() {
        _result = AdminUserDetailsResult(
          uid: _result.uid,
          profile: _result.profile,
          auth: AdminUserAuthDetails(
            uid: auth.uid,
            email: auth.email,
            emailVerified: auth.emailVerified,
            providerIds: auth.providerIds,
            createdAt: auth.createdAt,
            lastSignInAt: auth.lastSignInAt,
            disabled: response.disabled,
          ),
          profileNotFound: _result.profileNotFound,
          profileUnavailable: _result.profileUnavailable,
          profileFromCache: _result.profileFromCache,
          authNotFound: _result.authNotFound,
          authUnavailable: _result.authUnavailable,
        );
        _pendingSignature = null;
        _pendingOperationId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == AdminUserSuspensionAction.suspend
                  ? 'Conta suspensa.'
                  : 'Conta reativada.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      final terminal = isTerminalAdminOperationFailure(error);
      final code = error is FirebaseFunctionsException ? error.code : null;
      setState(() {
        _actionError = _safeActionError(error);
        if (terminal) {
          _pendingSignature = null;
          _pendingOperationId = null;
        }
        if (code == 'permission-denied') _actionsBlocked = true;
        if (code == 'not-found') {
          _result = AdminUserDetailsResult(
            uid: _result.uid,
            profile: _result.profile,
            auth: null,
            profileNotFound: _result.profileNotFound,
            profileUnavailable: _result.profileUnavailable,
            profileFromCache: _result.profileFromCache,
            authNotFound: true,
            authUnavailable: false,
          );
        }
      });
      if (code == 'failed-precondition' && mounted) {
        try {
          final refreshed = await widget.repository.loadDetails(_result.uid);
          if (!mounted) return;
          final previousDisabled = _result.auth?.disabled;
          setState(() {
            if (refreshed.auth != null &&
                refreshed.auth!.disabled != previousDisabled) {
              _result = refreshed;
            } else {
              _actionsBlocked = true;
            }
          });
        } on Object {
          if (mounted) setState(() => _actionsBlocked = true);
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goneMessage = _goneMessage;
    if (goneMessage != null) return _UserGone(message: goneMessage);

    final result = _result;
    final profile = result.profile;
    final auth = result.auth;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final eventsRepository = widget.eventsRepository;
    // Perfil sem conta no Auth é registro órfão: só a exclusão faz sentido.
    final canDelete = auth != null || (profile != null && result.authNotFound);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (result.profileFromCache) const _UserOfflineBanner(),
        if (result.authUnavailable) const _StatusBanner('Estado indisponível'),
        if (result.authNotFound) const _StatusBanner('Conta não encontrada'),
        if (result.profileNotFound)
          const _StatusBanner('Perfil não encontrado'),
        if (result.profileUnavailable)
          const _StatusBanner('Perfil indisponível nesta sessão em cache'),
        if (profile != null) ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  _UserAvatar(profile: profile, radius: 32),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.name.isEmpty ? 'Sem nome' : profile.name,
                          style: textTheme.headlineSmall,
                        ),
                        Text(
                          profile.handle.isEmpty
                              ? 'Sem handle'
                              : profile.handle,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        _DetailLine(
                          label: 'Modalidades favoritas',
                          value: _sportsLabel(profile.favoriteSports),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (auth != null) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Conta Firebase Auth', style: textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _DetailLine(label: 'UID', value: auth.uid),
                  _DetailLine(
                    label: 'E-mail principal',
                    value: auth.email ?? 'Não informado',
                  ),
                  _DetailLine(
                    label: 'E-mail verificado',
                    value: auth.emailVerified ? 'Sim' : 'Não',
                  ),
                  _DetailLine(
                    label: 'Provedores',
                    value: auth.providerIds.isEmpty
                        ? 'Não informado'
                        : auth.providerIds.join(', '),
                  ),
                  _DetailLine(
                    label: 'Criação da conta',
                    value: _dateLabel(auth.createdAt),
                  ),
                  _DetailLine(
                    label: 'Último login',
                    value: _dateLabel(auth.lastSignInAt),
                  ),
                  _DetailLine(
                    label: 'Estado',
                    value: auth.disabled ? 'Suspensa' : 'Ativa',
                    valueColor: auth.disabled ? colors.error : colors.secondary,
                  ),
                ],
              ),
            ),
          ),
        ] else if (profile == null &&
            !result.authUnavailable &&
            !result.profileUnavailable) ...<Widget>[
          const _StatusBanner('Usuário não encontrado'),
          _DetailLine(label: 'UID', value: result.uid),
        ],
        if (eventsRepository != null &&
            (profile != null || auth != null)) ...<Widget>[
          const SizedBox(height: 16),
          _OrganizedEventsCard(uid: result.uid, repository: eventsRepository),
        ],
        if (canDelete) ...<Widget>[
          const SizedBox(height: 16),
          _buildAccountActions(context, auth),
        ],
      ],
    );
  }

  /// Um motivo para todas as ações: suspender ou reativar (quando há conta
  /// no Auth) e excluir definitivamente.
  Widget _buildAccountActions(
    BuildContext context,
    AdminUserAuthDetails? auth,
  ) {
    final reason = normalizeAdminSuspensionReason(_reasonController.text);
    final reasonError = !_showReasonError
        ? null
        : reason.length < 10 || reason.length > 500
        ? 'Informe um motivo com 10 a 500 caracteres após normalização.'
        : null;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = TextStyle(color: colors.onSurfaceVariant);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Ações administrativas da conta', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Toda ação exige um motivo, registrado junto com a operação.',
              style: muted,
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
                      !_submitting &&
                      !_actionsBlocked &&
                      _pendingOperationId == null,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: 'Motivo obrigatório',
                    hintText: 'Descreva o motivo da ação administrativa',
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            if (_actionsBlocked) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'A ação está indisponível para esta conta. Recarregue os detalhes antes de tentar novamente.',
              ),
            ],
            if (_submitting) ...<Widget>[
              const SizedBox(height: 8),
              Semantics(
                label: 'Alteração da conta em andamento',
                liveRegion: true,
                child: const Text('Aguardando confirmação do servidor…'),
              ),
            ],
            if (auth != null) ...<Widget>[
              const SizedBox(height: 16),
              Text('Suspensão', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  'Suspender impede novos logins e revoga refresh tokens. Um ID token já emitido pode continuar válido até expirar; isto não é um bloqueio instantâneo.',
                  style: muted,
                ),
              ),
              const SizedBox(height: 12),
              _buildSuspensionButton(colors, auth),
              const SizedBox(height: 24),
              const Divider(),
            ],
            const SizedBox(height: 20),
            Text('Exclusão definitiva', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Text(_accountDeletionConsequences, style: muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
              ),
              onPressed: _submitting || _actionsBlocked
                  ? null
                  : _requestDeletion,
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: const Text('Excluir conta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuspensionButton(ColorScheme colors, AdminUserAuthDetails auth) {
    final action = auth.disabled
        ? AdminUserSuspensionAction.reactivate
        : AdminUserSuspensionAction.suspend;
    final suspending = action == AdminUserSuspensionAction.suspend;
    return FilledButton.icon(
      style: suspending
          ? FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            )
          : null,
      onPressed: _submitting || _actionsBlocked
          ? null
          : () => _requestAction(action),
      icon: _submitting && !_deleting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(suspending ? Icons.person_off_outlined : Icons.person_outline),
      label: Text(suspending ? 'Suspender conta' : 'Reativar conta'),
    );
  }
}

const String _accountDeletionConsequences =
    'Apaga de vez a conta de acesso, o perfil com os dados privados, as '
    'fotos, a reserva do username e as notificações; a pessoa não consegue '
    'mais entrar. Eventos organizados, participações, mensagens e avaliações '
    'continuam, como na exclusão feita pelo próprio app. A exclusão não pode '
    'ser desfeita.';

String _safeDeletionError(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'not-found' => 'A conta e o perfil já não existem.',
      'permission-denied' => 'Esta conta não pode ser excluída pelo painel.',
      'failed-precondition' => 'Você não pode excluir a sua própria conta administrativa.',
      'invalid-argument' => 'Revise o motivo e tente novamente.',
      'already-exists' => 'Houve um conflito na identificação da operação. Revise os dados e tente novamente.',
      _ => 'Não foi possível confirmar a exclusão. Tentar novamente repetirá a mesma solicitação com segurança.',
    };
  }
  return 'Não foi possível confirmar a exclusão. Seus dados foram preservados; tente novamente.';
}

/// Fim da página de uma conta que não existe mais, excluída aqui ou antes.
class _UserGone extends StatelessWidget {
  const _UserGone({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.person_off_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/users'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar para Usuários'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Os eventos mais recentes que a pessoa organizou, com atalho para cada um
/// — útil para revisar ou excluir antes de excluir a conta, que os mantém.
class _OrganizedEventsCard extends StatefulWidget {
  const _OrganizedEventsCard({required this.uid, required this.repository});

  final String uid;
  final AdminEventsRepository repository;

  @override
  State<_OrganizedEventsCard> createState() => _OrganizedEventsCardState();
}

class _OrganizedEventsCardState extends State<_OrganizedEventsCard> {
  late Future<List<AdminEventRecord>> _events = _load();

  Future<List<AdminEventRecord>> _load() =>
      widget.repository.loadOrganizedBy(widget.uid);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              'Eventos organizados',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          FutureBuilder<List<AdminEventRecord>>(
            future: _events,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      const Text(
                        'Não foi possível carregar os eventos organizados.',
                      ),
                      TextButton(
                        onPressed: () => setState(() => _events = _load()),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: LinearProgressIndicator(),
                );
              }
              final events = snapshot.data!;
              if (events.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Text('Nenhum evento organizado.'),
                );
              }
              final now = DateTime.now();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final event in events) ...<Widget>[
                    const Divider(),
                    AdminEventTile(
                      event: event,
                      now: now,
                      showOrganizer: false,
                      onTap: () => context.go(
                        '/events/${Uri.encodeComponent(event.id)}',
                      ),
                    ),
                  ],
                  if (events.length >= AdminEventsQueryPlan.pageSize) ...<Widget>[
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
                      child: Text('Mostrando os 20 mais recentes.'),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _safeActionError(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'not-found' => 'A conta Auth não foi encontrada.',
      'permission-denied' => 'Esta conta não pode ser alterada pelo painel.',
      'failed-precondition' => 'A ação não pode ser aplicada: a conta já está nesse estado ou é a sua própria conta administrativa.',
      'invalid-argument' => 'Revise o motivo e tente novamente.',
      'already-exists' => 'Houve um conflito na identificação da operação. Revise os dados e tente novamente.',
      _ => 'Não foi possível confirmar a operação. Tentar novamente repetirá a mesma solicitação com segurança.',
    };
  }
  return 'Não foi possível confirmar a operação. Seus dados foram preservados; tente novamente.';
}

class _AdminUserTile extends StatelessWidget {
  const _AdminUserTile({required this.item, required this.onTap});

  final AdminUserListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final profile = item.profile;
    final (status, tone) = switch (item.authState) {
      AdminUserAuthState.active => ('Ativa', AdminStatusTone.positive),
      AdminUserAuthState.suspended => ('Suspensa', AdminStatusTone.negative),
      AdminUserAuthState.notFound => (
        'Conta não encontrada',
        AdminStatusTone.neutral,
      ),
      AdminUserAuthState.unavailable => (
        'Estado indisponível',
        AdminStatusTone.neutral,
      ),
    };
    final pill = AdminStatusPill(label: status, tone: tone);
    // Em telas estreitas o estado desce para não espremer o nome.
    final compact = MediaQuery.sizeOf(context).width < 600;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
        child: Row(
          children: <Widget>[
            _UserAvatar(profile: profile),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    profile.name.isEmpty ? 'Sem nome' : profile.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    profile.handle.isEmpty ? 'Sem handle' : profile.handle,
                    style: muted,
                  ),
                  if (profile.favoriteSports.isNotEmpty)
                    Text(
                      _sportsLabel(profile.favoriteSports),
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

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.profile, this.radius = 22});

  final AdminUserProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = Uri.tryParse(profile.avatarUrl);
    final hasImage =
        url != null && url.scheme == 'https' && url.host.isNotEmpty;
    final initials = profile.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.characters.first.toUpperCase())
        .take(2)
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundImage: hasImage ? NetworkImage(profile.avatarUrl) : null,
      child: hasImage
          ? null
          : initials.isEmpty
          ? const Icon(Icons.person_outline)
          : ExcludeSemantics(
              child: Text(
                initials,
                style: TextStyle(
                  fontFamily: AdminTheme.displayFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: radius * 0.8,
                ),
              ),
            ),
    );
  }
}

/// "Rótulo: valor" num só texto selecionável, com o rótulo esmaecido.
class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

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
                color: valueColor ?? colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersSkeleton extends StatelessWidget {
  const _UsersSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Carregando usuários',
      liveRegion: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            const LinearProgressIndicator(),
            for (var row = 0; row < 4; row++)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(radius: 22, backgroundColor: block),
                    const SizedBox(width: 16),
                    Container(
                      width: 180,
                      height: 14,
                      decoration: BoxDecoration(
                        color: block,
                        borderRadius: BorderRadius.circular(4),
                      ),
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

class _UsersEmpty extends StatelessWidget {
  const _UsersEmpty({
    required this.exact,
    required this.notFound,
    required this.query,
    this.onClear,
  });

  final bool exact;
  final bool notFound;
  final String query;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          const Icon(Icons.person_search_outlined, size: 40),
          const SizedBox(height: 8),
          Text(
            exact && notFound
                ? 'Nenhuma conta encontrada.'
                : query.trim().isEmpty
                ? 'Nenhum perfil encontrado.'
                : 'Nenhum usuário encontrado para esta busca.',
            textAlign: TextAlign.center,
          ),
          if (onClear != null) ...<Widget>[
            const SizedBox(height: 12),
            TextButton(onPressed: onClear, child: const Text('Limpar busca')),
          ],
        ],
      ),
    ),
  );
}

class _UsersError extends StatelessWidget {
  const _UsersError({
    required this.onRetry,
    this.message = 'Não foi possível carregar os usuários.',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) => _MessageCard(
    message: message,
    action: FilledButton(
      onPressed: onRetry,
      child: const Text('Tentar novamente'),
    ),
  );
}

class _UsersInlineError extends StatelessWidget {
  const _UsersInlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _MessageCard(
    message: 'Não foi possível carregar esta página de usuários.',
    action: TextButton(
      onPressed: onRetry,
      child: const Text('Tentar novamente'),
    ),
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(child: Semantics(liveRegion: true, child: Text(message))),
          ],
        ),
      ),
    ),
  );
}

class _UserOfflineBanner extends StatelessWidget {
  const _UserOfflineBanner();

  @override
  Widget build(BuildContext context) => const _StatusBanner(
    'Exibindo dados em cache. Algumas informações Auth podem estar indisponíveis offline.',
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.action});

  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          action,
        ],
      ),
    ),
  );
}

String _sportsLabel(List<String> sports) {
  if (sports.isEmpty) return 'Nenhuma selecionada';
  const labels = <String, String>{
    'futebol': 'Futebol',
    'basquete': 'Basquete',
    'volei': 'Vôlei',
    'tenisDeMesa': 'Tênis de mesa',
    'futsal': 'Futsal',
    'corrida': 'Corrida',
    'ciclismo': 'Ciclismo',
    'caminhada': 'Caminhada',
  };
  return sports.map((sport) => labels[sport] ?? sport).join(', ');
}

String _dateLabel(DateTime? date) =>
    date == null ? 'Não informado' : date.toLocal().toString().split('.').first;
