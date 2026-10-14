import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../data/admin_place_model.dart';
import '../data/admin_places_repository.dart';

typedef AdminPlaceMapPickerBuilder = Widget Function(
  BuildContext context,
  LatLng selectedPoint,
  ValueChanged<LatLng> onSelected,
);

class AdminPlaceFormPage extends StatefulWidget {
  const AdminPlaceFormPage({
    required this.repository,
    this.placeId,
    this.mapPickerBuilder,
    super.key,
  });

  final AdminPlacesRepository repository;
  final String? placeId;
  final AdminPlaceMapPickerBuilder? mapPickerBuilder;

  @override
  State<AdminPlaceFormPage> createState() => _AdminPlaceFormPageState();
}

class _AdminPlaceFormPageState extends State<AdminPlaceFormPage> {
  late Stream<AdminPlaceRecord?> _placeStream;

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null) _placeStream = widget.repository.watchPlace(id);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.placeId == null) {
      return _AdminPlaceEditor(
        repository: widget.repository,
        mapPickerBuilder: widget.mapPickerBuilder,
      );
    }
    return StreamBuilder<AdminPlaceRecord?>(
      stream: _placeStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _PlaceLoadFailure(
            message: 'Não foi possível carregar este Local Esportivo.',
            onRetry: () => setState(() {
              _placeStream = widget.repository.watchPlace(widget.placeId!);
            }),
          );
        }
        if (!snapshot.hasData) return const _PlaceDetailsLoading();
        final place = snapshot.data;
        if (place == null) {
          return const _PlaceLoadFailure(
            message: 'Local Esportivo não encontrado.',
          );
        }
        return _AdminPlaceEditor(
          key: ValueKey<String>(place.id),
          repository: widget.repository,
          place: place,
          mapPickerBuilder: widget.mapPickerBuilder,
        );
      },
    );
  }
}

class _AdminPlaceEditor extends StatefulWidget {
  const _AdminPlaceEditor({
    required this.repository,
    this.place,
    this.mapPickerBuilder,
    super.key,
  });

  final AdminPlacesRepository repository;
  final AdminPlaceRecord? place;
  final AdminPlaceMapPickerBuilder? mapPickerBuilder;

  @override
  State<_AdminPlaceEditor> createState() => _AdminPlaceEditorState();
}

class _AdminPlaceEditorState extends State<_AdminPlaceEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  late final Map<String, FocusNode> _fieldFocusNodes = <String, FocusNode>{
    for (final key in <String>[
      'name',
      'description',
      'street',
      'number',
      'complement',
      'neighborhood',
      'city',
      'state',
      'postalCode',
      'sports',
      'primarySport',
      'latitude',
      'longitude',
      'imageUrl',
    ])
      key: key == 'name' ? _nameFocus : FocusNode(),
  };
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();
  final _neighborhood = TextEditingController();
  final _city = TextEditingController();
  final _postalCode = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _imageUrl = TextEditingController();

  late String _stateCode;
  late List<String> _sports;
  String? _primarySport;
  double? _latitudeValue;
  double? _longitudeValue;
  Timestamp? _baselineUpdatedAt;
  AdminPlaceRecord? _latestRemotePlace;
  bool _dirty = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _operationError;
  AdminPlaceOperationErrorCode? _lastOperationError;

  bool get _isCreating => widget.place == null;

  @override
  void initState() {
    super.initState();
    _stateCode = 'RS';
    _sports = <String>[];
    final place = widget.place;
    if (place != null) {
      _latestRemotePlace = place;
      _baselineUpdatedAt = place.updatedAt;
      _populate(place.toDraft());
    } else {
      _latitudeValue = adminTaquaraCenter.latitude;
      _longitudeValue = adminTaquaraCenter.longitude;
      _latitude.text = _formatCoordinate(_latitudeValue!);
      _longitude.text = _formatCoordinate(_longitudeValue!);
    }
  }

  @override
  void didUpdateWidget(covariant _AdminPlaceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latest = widget.place;
    if (latest == null) return;
    _latestRemotePlace = latest;
    if (_baselineUpdatedAt == null || !_dirty) {
      if (_baselineUpdatedAt == null ||
          !_sameTimestamp(_baselineUpdatedAt!, latest.updatedAt)) {
        _populate(latest.toDraft());
        _baselineUpdatedAt = latest.updatedAt;
        _dirty = false;
        _operationError = null;
      }
    } else if (!_sameTimestamp(_baselineUpdatedAt!, latest.updatedAt)) {
      // Keep the values currently being edited. The transaction still uses the
      // original version and will reject a stale submit.
      _operationError = 'Este local mudou desde que você abriu o formulário. Seus dados digitados foram preservados; recarregue para revisar a versão mais recente.';
    }
  }

  void _populate(AdminPlaceDraft draft) {
    _name.text = draft.name;
    _description.text = draft.description;
    _street.text = draft.street;
    _number.text = draft.number;
    _complement.text = draft.complement;
    _neighborhood.text = draft.neighborhood;
    _city.text = draft.city;
    _stateCode = draft.state;
    _postalCode.text = formatAdminPostalCode(draft.postalCode);
    _sports = List<String>.of(draft.sports);
    _primarySport = draft.primarySport;
    _latitudeValue = draft.latitude;
    _longitudeValue = draft.longitude;
    _latitude.text = draft.latitude == null
        ? ''
        : _formatCoordinate(draft.latitude!);
    _longitude.text = draft.longitude == null
        ? ''
        : _formatCoordinate(draft.longitude!);
    _imageUrl.text = draft.imageUrl;
  }

  @override
  void dispose() {
    for (final focusNode in _fieldFocusNodes.values) {
      if (!identical(focusNode, _nameFocus)) focusNode.dispose();
    }
    _nameFocus.dispose();
    for (final controller in <TextEditingController>[
      _name,
      _description,
      _street,
      _number,
      _complement,
      _neighborhood,
      _city,
      _postalCode,
      _latitude,
      _longitude,
      _imageUrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  AdminPlaceDraft get _draft => AdminPlaceDraft(
    name: _name.text,
    description: _description.text,
    street: _street.text,
    number: _number.text,
    complement: _complement.text,
    neighborhood: _neighborhood.text,
    city: _city.text,
    state: _stateCode,
    postalCode: _postalCode.text,
    sports: List<String>.unmodifiable(_sports),
    primarySport: _primarySport,
    latitude: _latitudeValue,
    longitude: _longitudeValue,
    imageUrl: _imageUrl.text,
  );

  void _markDirty() {
    setState(() => _dirty = true);
  }

  String? _draftError(String key) => _submitted ? _draft.validate()[key] : null;

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _operationError = null;
      _lastOperationError = null;
    });
    final validForm = _formKey.currentState?.validate() ?? false;
    final errors = _draft.validate();
    if (!validForm || errors.isNotEmpty) {
      _focusFirstError(errors);
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_isCreating) {
        final id = await widget.repository.createPlace(_draft);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local cadastrado como inativo.')),
        );
        context.go('/places/${Uri.encodeComponent(id)}');
      } else {
        await widget.repository.updatePlace(
          widget.place!.id,
          _draft,
          expectedUpdatedAt: _baselineUpdatedAt!,
        );
        if (!mounted) return;
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local atualizado com sucesso.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _operationError = _messageForError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _focusFirstError(Map<String, String> errors) {
    final firstInvalidField = errors.isEmpty ? null : errors.keys.first;
    (_fieldFocusNodes[firstInvalidField] ?? _nameFocus).requestFocus();
  }

  String _messageForError(Object error) {
    if (error is AdminPlaceOperationError) {
      _lastOperationError = error.code;
      if (error.code == AdminPlaceOperationErrorCode.conflict) {
        return '${error.message} Seus campos digitados foram preservados.';
      }
      return error.message;
    }
    if (error is FirebaseException &&
        (error.code == 'unavailable' ||
            error.code == 'network-request-failed')) {
      return 'Sem conexão com o servidor. Os dados foram preservados; reconecte e tente novamente.';
    }
    return 'Não foi possível salvar no servidor. Os dados foram preservados; tente novamente.';
  }

  Future<void> _reloadLatest() async {
    final id = widget.place?.id;
    if (id == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final latest = await widget.repository.getPlace(id);
      if (!mounted) return;
      if (latest == null) {
        setState(() {
          _operationError = 'Este Local Esportivo não existe mais.';
          _lastOperationError = AdminPlaceOperationErrorCode.notFound;
        });
        return;
      }
      setState(() {
        _latestRemotePlace = latest;
        _populate(latest.toDraft());
        _baselineUpdatedAt = latest.updatedAt;
        _dirty = false;
        _operationError = null;
        _lastOperationError = null;
        _submitted = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _operationError = 'Não foi possível recarregar a versão do servidor. Seus dados digitados foram preservados.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    final place = widget.place!;
    final isDeactivating = status == 'inactive';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDeactivating ? 'Desativar local?' : 'Ativar local?'),
        content: Text(
          isDeactivating
              ? '“${place.name}” deixará de aparecer no mapa, nas pesquisas comuns e na criação de novos eventos. Referências históricas continuarão funcionando.'
              : '“${place.name}” voltará a aparecer no mapa, nas pesquisas e poderá ser escolhido em novos eventos.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isDeactivating ? 'Desativar' : 'Ativar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _submitting = true;
      _operationError = null;
      _lastOperationError = null;
    });
    try {
      await widget.repository.setPlaceStatus(
        place.id,
        status,
        expectedUpdatedAt: _baselineUpdatedAt!,
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDeactivating ? 'Local desativado.' : 'Local ativado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _operationError = _messageForError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestLeave() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
          'Há alterações não salvas. Se sair agora, elas serão descartadas.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair sem salvar'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) context.go('/places');
  }

  Future<void> _onPopInvoked(bool didPop) async {
    if (!didPop && _dirty) await _requestLeave();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final fieldErrors = draft.validate();
    final remoteChanged =
        _latestRemotePlace != null &&
        _baselineUpdatedAt != null &&
        !_sameTimestamp(_baselineUpdatedAt!, _latestRemotePlace!.updatedAt);
    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Voltar para locais',
                onPressed: _dirty ? _requestLeave : () => context.go('/places'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  _isCreating
                      ? 'Cadastrar Local Esportivo'
                      : widget.place!.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (!_isCreating)
                Chip(
                  label: Text(widget.place!.isActive ? 'Ativo' : 'Inativo'),
                  avatar: Icon(
                    widget.place!.isActive
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.place?.isFromCache == true) const _CachedPlaceBanner(),
          if (remoteChanged)
            _FormMessage(
              message: 'Outra alteração foi recebida do servidor. Seus campos foram preservados; recarregue para usar a versão atual.',
              actionLabel: 'Recarregar dados',
              onAction: _reloadLatest,
            ),
          if (_submitted && fieldErrors.isNotEmpty)
            _ValidationSummary(errors: fieldErrors),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Informações do local',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _name,
                  focusNode: _nameFocus,
                  label: 'Nome',
                  keyName: 'name',
                  maxLength: 120,
                  onChanged: (_) => _markDirty(),
                ),
                _textField(
                  controller: _description,
                  label: 'Descrição',
                  keyName: 'description',
                  maxLength: 1500,
                  maxLines: 4,
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 10),
                Text('Endereço', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _textField(
                  controller: _street,
                  label: 'Rua',
                  keyName: 'street',
                  maxLength: 160,
                  onChanged: (_) => _markDirty(),
                ),
                _textField(
                  controller: _number,
                  label: 'Número (opcional)',
                  keyName: 'number',
                  maxLength: 20,
                  onChanged: (_) => _markDirty(),
                ),
                _textField(
                  controller: _complement,
                  label: 'Complemento (opcional)',
                  keyName: 'complement',
                  maxLength: 120,
                  onChanged: (_) => _markDirty(),
                ),
                _textField(
                  controller: _neighborhood,
                  label: 'Bairro (opcional)',
                  keyName: 'neighborhood',
                  maxLength: 100,
                  onChanged: (_) => _markDirty(),
                ),
                _textField(
                  controller: _city,
                  label: 'Cidade',
                  keyName: 'city',
                  maxLength: 100,
                  onChanged: (_) => _markDirty(),
                ),
                Semantics(
                  label: 'UF brasileira',
                  container: true,
                  explicitChildNodes: true,
                  child: _statePicker(),
                ),
                _textField(
                  controller: _postalCode,
                  label: 'CEP (opcional)',
                  keyName: 'postalCode',
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 10),
                Text(
                  'Modalidades',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Semantics(
                  // Give keyboard users a direct focus target for the choice set.
                  child: Focus(
                    focusNode: _fieldFocusNodes['sports'],
                    child: Semantics(
                      label: 'Modalidades disponíveis',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: adminPlaceSports.map((sport) {
                          final selected = _sports.contains(sport);
                          return FilterChip(
                            label: Text(_sportLabel(sport)),
                            selected: selected,
                            onSelected: _submitting
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value) {
                                        _sports = <String>[..._sports, sport];
                                        _primarySport ??= sport;
                                      } else {
                                        _sports = _sports
                                            .where((item) => item != sport)
                                            .toList();
                                        if (_primarySport == sport) {
                                          _primarySport = _sports.isEmpty
                                              ? null
                                              : _sports.first;
                                        }
                                      }
                                      _dirty = true;
                                    });
                                  },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                if (_draftError('sports') case final message?)
                  _InlineFieldError(message: message),
                const SizedBox(height: 8),
                SizedBox(
                  width: 330,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'primary-${_primarySport ?? ''}-${_sports.join(',')}',
                    ),
                    initialValue: _sports.contains(_primarySport)
                        ? _primarySport
                        : null,
                    focusNode: _fieldFocusNodes['primarySport'],
                    decoration: InputDecoration(
                      labelText: 'Modalidade principal',
                      errorText: _draftError('primarySport'),
                    ),
                    items: _sports
                        .map(
                          (sport) => DropdownMenuItem<String>(
                            value: sport,
                            child: Text(_sportLabel(sport)),
                          ),
                        )
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() {
                            _primarySport = value;
                            _dirty = true;
                          }),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Localização',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Toque no mapa para posicionar o marcador ou edite latitude e longitude.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                _buildMapPicker(draft),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _coordinateField(
                        controller: _latitude,
                        label: 'Latitude',
                        keyName: 'latitude',
                        onChanged: _updateCoordinatesFromText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _coordinateField(
                        controller: _longitude,
                        label: 'Longitude',
                        keyName: 'longitude',
                        onChanged: _updateCoordinatesFromText,
                      ),
                    ),
                  ],
                ),
                if (draft.isFarFromTaquara)
                  const _FormMessage(
                    message: 'Este ponto está a mais de 50 km de Taquara. Confira se as coordenadas estão corretas; o aviso não impede o cadastro.',
                    isWarning: true,
                  ),
                const SizedBox(height: 12),
                Text('Imagem', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _textField(
                  controller: _imageUrl,
                  label: 'URL HTTPS da imagem',
                  keyName: 'imageUrl',
                  maxLength: 2048,
                  keyboardType: TextInputType.url,
                  onChanged: (_) => _markDirty(),
                ),
                _ImagePreview(url: _imageUrl.text),
                const SizedBox(height: 24),
                if (_operationError != null)
                  _FormMessage(
                    message: _operationError!,
                    actionLabel:
                        _lastOperationError ==
                                AdminPlaceOperationErrorCode.conflict ||
                            _lastOperationError ==
                                AdminPlaceOperationErrorCode.notFound
                        ? 'Recarregar dados'
                        : null,
                    onAction:
                        _lastOperationError ==
                                AdminPlaceOperationErrorCode.conflict ||
                            _lastOperationError ==
                                AdminPlaceOperationErrorCode.notFound
                        ? _reloadLatest
                        : null,
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isCreating ? 'Cadastrar inativo' : 'Salvar alterações',
                      ),
                    ),
                    if (!_isCreating)
                      OutlinedButton.icon(
                        onPressed: _submitting || _dirty
                            ? null
                            : () => _changeStatus(
                                widget.place!.isActive ? 'inactive' : 'active',
                              ),
                        icon: Icon(
                          widget.place!.isActive
                              ? Icons.pause_circle_outline
                              : Icons.check_circle_outline,
                        ),
                        label: Text(
                          widget.place!.isActive
                              ? 'Desativar local'
                              : 'Ativar local',
                        ),
                      ),
                    OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : (_dirty
                                ? _requestLeave
                                : () => context.go('/places')),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statePicker() => SizedBox(
    width: 220,
    child: DropdownButtonFormField<String>(
      key: ValueKey<String>('state-$_stateCode'),
      initialValue: _stateCode,
      focusNode: _fieldFocusNodes['state'],
      decoration: InputDecoration(
        labelText: 'UF',
        errorText: _draftError('state'),
      ),
      items: (adminBrazilianStates.toList()..sort())
          .map(
            (state) =>
                DropdownMenuItem<String>(value: state, child: Text(state)),
          )
          .toList(),
      onChanged: _submitting
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  _stateCode = value;
                  _dirty = true;
                });
              }
            },
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String keyName,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: TextFormField(
        key: ValueKey<String>('place-$keyName'),
        controller: controller,
        focusNode: focusNode ?? _fieldFocusNodes[keyName],
        enabled: !_submitting,
        decoration: InputDecoration(
          labelText: label,
          errorText: _draftError(keyName),
          alignLabelWithHint: maxLines > 1,
        ),
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        validator: (_) => _draft.validate()[keyName],
      ),
    ),
  );

  Widget _coordinateField({
    required TextEditingController controller,
    required String label,
    required String keyName,
    required ValueChanged<String> onChanged,
  }) => TextFormField(
    key: ValueKey<String>('place-$keyName'),
    controller: controller,
    focusNode: _fieldFocusNodes[keyName],
    enabled: !_submitting,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
    ],
    decoration: InputDecoration(
      labelText: label,
      errorText: _draftError(keyName),
    ),
    onChanged: onChanged,
    validator: (_) => _draft.validate()[keyName],
  );

  Widget _buildMapPicker(AdminPlaceDraft draft) {
    final point = LatLng(
      draft.latitude ?? adminTaquaraCenter.latitude,
      draft.longitude ?? adminTaquaraCenter.longitude,
    );
    final builder = widget.mapPickerBuilder;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: AspectRatio(
        aspectRatio: 16 / 8,
        child: builder == null
            ? AdminPlaceMapPicker(
                selectedPoint: point,
                onSelected: _onPointSelected,
              )
            : builder(context, point, _onPointSelected),
      ),
    );
  }

  void _onPointSelected(LatLng point) {
    setState(() {
      _latitudeValue = point.latitude;
      _longitudeValue = point.longitude;
      _latitude.text = _formatCoordinate(point.latitude);
      _longitude.text = _formatCoordinate(point.longitude);
      _dirty = true;
    });
  }

  void _updateCoordinatesFromText(String _) {
    final latitude = double.tryParse(_latitude.text.replaceAll(',', '.'));
    final longitude = double.tryParse(_longitude.text.replaceAll(',', '.'));
    setState(() {
      _latitudeValue = latitude;
      _longitudeValue = longitude;
      _dirty = true;
    });
  }
}

class AdminPlaceMapPicker extends StatefulWidget {
  const AdminPlaceMapPicker({
    required this.selectedPoint,
    required this.onSelected,
    super.key,
  });

  final LatLng selectedPoint;
  final ValueChanged<LatLng> onSelected;

  @override
  State<AdminPlaceMapPicker> createState() => _AdminPlaceMapPickerState();
}

class _AdminPlaceMapPickerState extends State<AdminPlaceMapPicker> {
  final MapController _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(covariant AdminPlaceMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        (oldWidget.selectedPoint.latitude != widget.selectedPoint.latitude ||
            oldWidget.selectedPoint.longitude !=
                widget.selectedPoint.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.move(widget.selectedPoint, 14);
      });
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.selectedPoint,
            initialZoom: 14,
            onMapReady: () => _ready = true,
            onTap: (_, point) => widget.onSelected(point),
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'br.com.compy.admin',
            ),
            MarkerLayer(
              markers: <Marker>[
                Marker(
                  point: widget.selectedPoint,
                  width: 48,
                  height: 48,
                  child: const Icon(
                    Icons.location_pin,
                    size: 42,
                    color: Color(0xFFBA1A1A),
                    semanticLabel: 'Ponto escolhido no mapa',
                  ),
                ),
              ],
            ),
          ],
        ),
        const Positioned(
          right: 8,
          bottom: 8,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white70),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text('© OpenStreetMap contributors'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url.trim());
    final valid = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    return Semantics(
      label: 'Prévia da imagem do Local Esportivo',
      container: true,
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: 220,
          height: 140,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: valid
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _ImagePlaceholder(text: 'Prévia indisponível'),
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const _ImagePlaceholder(text: 'Carregando prévia…'),
                )
              : const _ImagePlaceholder(text: 'A prévia aparecerá aqui'),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      const Icon(Icons.image_outlined, size: 32),
      const SizedBox(height: 6),
      Text(text),
    ],
  );
}

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.errors});

  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Resumo de erros do formulário',
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Revise os campos destacados:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ...errors.values.map((error) => Text('• $error')),
          ],
        ),
      ),
    ),
  );
}

class _InlineFieldError extends StatelessWidget {
  const _InlineFieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class _FormMessage extends StatelessWidget {
  const _FormMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isWarning = false,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isWarning;

  @override
  Widget build(BuildContext context) => Card(
    color: isWarning
        ? const Color(0xFFFFF3CD)
        : Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(isWarning ? Icons.warning_amber_outlined : Icons.info_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    ),
  );
}

class _CachedPlaceBanner extends StatelessWidget {
  const _CachedPlaceBanner();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'Dados carregados do cache. Conecte-se para salvar alterações.',
      ),
    ),
  );
}

class _PlaceDetailsLoading extends StatelessWidget {
  const _PlaceDetailsLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

class _PlaceLoadFailure extends StatelessWidget {
  const _PlaceLoadFailure({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 8),
          Text(message),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    ),
  );
}

String _sportLabel(String sport) => switch (sport) {
  'futebol' => 'Futebol',
  'basquete' => 'Basquete',
  'volei' => 'Vôlei',
  'tenisDeMesa' => 'Tênis de mesa',
  'futsal' => 'Futsal',
  'corrida' => 'Corrida',
  'ciclismo' => 'Ciclismo',
  'caminhada' => 'Caminhada',
  _ => sport,
};

String _formatCoordinate(double value) => value.toStringAsFixed(6);

bool _sameTimestamp(Timestamp left, Timestamp right) =>
    left.seconds == right.seconds && left.nanoseconds == right.nanoseconds;
