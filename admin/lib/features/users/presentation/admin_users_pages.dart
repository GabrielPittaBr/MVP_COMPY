import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Text('Usuários', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
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
        const SizedBox(height: 12),
        if (state.isFromCache) const _UserOfflineBanner(),
        const SizedBox(height: 12),
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
          ...state.items.map(
            (item) => _AdminUserTile(
              item: item,
              onTap: () =>
                  context.go('/users/${Uri.encodeComponent(item.profile.uid)}'),
            ),
          ),
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.hasMore && !state.isLoadingMore)
            Align(
              alignment: Alignment.center,
              child: OutlinedButton(
                onPressed: _controller.loadNextPage,
                child: const Text('Carregar mais usuários'),
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
    this.initialDetails,
    super.key,
  });

  final String uid;
  final AdminUsersRepository? repository;
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
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Voltar para Usuários',
              onPressed: () => context.go('/users'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detalhes do Usuário',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
  });

  final AdminUserDetailsResult result;
  final AdminUsersRepository repository;

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

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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
        : _newUuidV4();
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
      final operationStatus =
          error is FirebaseFunctionsException && error.details is Map
          ? (error.details as Map)['operationStatus']
          : null;
      final terminal = _isTerminalFailure(error) || operationStatus == 'failed';
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
    final result = _result;
    final profile = result.profile;
    final auth = result.auth;
    final textTheme = Theme.of(context).textTheme;
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
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  _UserAvatar(profile: profile, radius: 30),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.name.isEmpty ? 'Sem nome' : profile.name,
                          style: textTheme.titleLarge,
                        ),
                        Text(
                          profile.handle.isEmpty
                              ? 'Sem handle'
                              : profile.handle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Modalidades favoritas: ${_sportsLabel(profile.favoriteSports)}',
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
              padding: const EdgeInsets.all(20),
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
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSuspensionActions(context, auth),
        ] else if (profile == null &&
            !result.authUnavailable &&
            !result.profileUnavailable) ...<Widget>[
          const _StatusBanner('Usuário não encontrado'),
          _DetailLine(label: 'UID', value: result.uid),
        ],
      ],
    );
  }

  Widget _buildSuspensionActions(
    BuildContext context,
    AdminUserAuthDetails auth,
  ) {
    final action = auth.disabled
        ? AdminUserSuspensionAction.reactivate
        : AdminUserSuspensionAction.suspend;
    final reason = normalizeAdminSuspensionReason(_reasonController.text);
    final reasonError = !_showReasonError
        ? null
        : reason.length < 10 || reason.length > 500
        ? 'Informe um motivo com 10 a 500 caracteres após normalização.'
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Ações administrativas da conta',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Suspender impede novos logins e revoga refresh tokens. Um ID token já emitido pode continuar válido até expirar; isto não é um bloqueio instantâneo.',
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Motivo obrigatório',
              textField: true,
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _submitting || _actionsBlocked
                      ? null
                      : () => _requestAction(action),
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          action == AdminUserSuspensionAction.suspend
                              ? Icons.person_off_outlined
                              : Icons.person_outline,
                        ),
                  label: Text(
                    action == AdminUserSuspensionAction.suspend
                        ? 'Suspender conta'
                        : 'Reativar conta',
                  ),
                ),
                if (_submitting)
                  Semantics(
                    label: 'Alteração da conta em andamento',
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

String _newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

bool _isTerminalFailure(Object error) {
  if (error is! FirebaseFunctionsException) return false;
  return const <String>{
    'invalid-argument',
    'not-found',
    'permission-denied',
    'failed-precondition',
    'already-exists',
  }.contains(error.code);
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
    final profile = item.profile;
    final status = switch (item.authState) {
      AdminUserAuthState.active => 'Ativa',
      AdminUserAuthState.suspended => 'Suspensa',
      AdminUserAuthState.notFound => 'Conta não encontrada',
      AdminUserAuthState.unavailable => 'Estado indisponível',
    };
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: _UserAvatar(profile: profile),
        title: Text(profile.name.isEmpty ? 'Sem nome' : profile.name),
        subtitle: Text(
          '${profile.handle.isEmpty ? 'Sem handle' : profile.handle}\n'
          'Modalidades favoritas: ${_sportsLabel(profile.favoriteSports)}\n'
          'Estado: $status',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
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
    return CircleAvatar(
      radius: radius,
      backgroundImage: hasImage ? NetworkImage(profile.avatarUrl) : null,
      child: hasImage ? null : const Icon(Icons.person_outline),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: SelectableText('$label: $value'),
  );
}

class _UsersSkeleton extends StatelessWidget {
  const _UsersSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carregando usuários',
    liveRegion: true,
    child: Column(
      children: List<Widget>.generate(
        4,
        (index) => const Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.person_outline)),
            title: LinearProgressIndicator(),
            subtitle: Text(' '),
          ),
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Semantics(liveRegion: true, child: Text(message)),
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
