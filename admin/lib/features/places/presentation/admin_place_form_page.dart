import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/shell/admin_shell.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_status_pill.dart';
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
      'accessType',
      'contactPhone',
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
  final _contactPhone = TextEditingController();

  late String _stateCode;
  late List<String> _sports;
  late List<_PlaceImageInput> _images;
  String? _accessType;
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
    _images = <_PlaceImageInput>[_PlaceImageInput()];
    _accessType = 'public';
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
    for (final image in _images) {
      image.dispose();
    }
    _images = draft.effectiveImages
        .map((image) => _PlaceImageInput(url: image.url, source: image.source))
        .toList();
    _accessType = draft.accessType;
    _contactPhone.text = formatAdminBrazilianPhone(draft.contactPhone);
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
      _contactPhone,
    ]) {
      controller.dispose();
    }
    for (final image in _images) {
      image.dispose();
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
    imageUrl: _images.isEmpty ? '' : _images.first.url.text,
    images: List<AdminPlaceImage>.unmodifiable(
      _images.map(
        (image) =>
            AdminPlaceImage(url: image.url.text, source: image.source.text),
      ),
    ),
    accessType: _accessType,
    contactPhone: _contactPhone.text,
  );

  void _addImage() {
    if (_images.length >= 8) return;
    setState(() {
      _images.add(_PlaceImageInput());
      _dirty = true;
    });
  }

  void _removeImage(int index) {
    if (_images.length <= 1) return;
    setState(() {
      _images.removeAt(index).dispose();
      _dirty = true;
    });
  }

  void _moveImage(int index, int offset) {
    final destination = index + offset;
    if (destination < 0 || destination >= _images.length) return;
    setState(() {
      final image = _images.removeAt(index);
      _images.insert(destination, image);
      _dirty = true;
    });
  }

  void _markDirty() {
    setState(() => _dirty = true);
  }

  Map<String, String> get _validationErrors =>
      _draft.validate(requireAccessType: _isCreating);

  String? _draftError(String key) => _submitted ? _validationErrors[key] : null;

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _operationError = null;
      _lastOperationError = null;
    });
    final validForm = _formKey.currentState?.validate() ?? false;
    final errors = _validationErrors;
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
    final focusKey = firstInvalidField == 'images'
        ? 'imageUrl'
        : firstInvalidField;
    (_fieldFocusNodes[focusKey] ?? _nameFocus).requestFocus();
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
        padding: adminPagePadding(context),
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Voltar para locais',
                        onPressed: _dirty
                            ? _requestLeave
                            : () => context.go('/places'),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _isCreating
                              ? 'Cadastrar Local Esportivo'
                              : widget.place!.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      if (!_isCreating) ...<Widget>[
                        const SizedBox(width: 12),
                        AdminStatusPill(
                          label: widget.place!.isActive ? 'Ativo' : 'Inativo',
                          tone: widget.place!.isActive
                              ? AdminStatusTone.positive
                              : AdminStatusTone.neutral,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (widget.place?.isFromCache == true)
                    const _CachedPlaceBanner(),
                  if (remoteChanged)
                    _FormMessage(
                      message: 'Outra alteração foi recebida do servidor. Seus campos foram preservados; recarregue para usar a versão atual.',
                      actionLabel: 'Recarregar dados',
                      onAction: _reloadLatest,
                    ),
                  if (_submitted && fieldErrors.isNotEmpty)
                    _ValidationSummary(errors: fieldErrors),
                  Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _FormSection(
                          title: 'Informações do local',
                          children: <Widget>[
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
                          ],
                        ),
                        _FormSection(
                          title: 'Endereço',
                          children: <Widget>[
                            _FieldRow(<(int, Widget)>[
                              (
                                3,
                                _textField(
                                  controller: _street,
                                  label: 'Rua',
                                  keyName: 'street',
                                  maxLength: 160,
                                  onChanged: (_) => _markDirty(),
                                ),
                              ),
                              (
                                1,
                                _textField(
                                  controller: _number,
                                  label: 'Número (opcional)',
                                  keyName: 'number',
                                  maxLength: 20,
                                  onChanged: (_) => _markDirty(),
                                ),
                              ),
                            ]),
                            _FieldRow(<(int, Widget)>[
                              (
                                1,
                                _textField(
                                  controller: _complement,
                                  label: 'Complemento (opcional)',
                                  keyName: 'complement',
                                  maxLength: 120,
                                  onChanged: (_) => _markDirty(),
                                ),
                              ),
                              (
                                1,
                                _textField(
                                  controller: _neighborhood,
                                  label: 'Bairro (opcional)',
                                  keyName: 'neighborhood',
                                  maxLength: 100,
                                  onChanged: (_) => _markDirty(),
                                ),
                              ),
                            ]),
                            _FieldRow(<(int, Widget)>[
                              (
                                2,
                                _textField(
                                  controller: _city,
                                  label: 'Cidade',
                                  keyName: 'city',
                                  maxLength: 100,
                                  onChanged: (_) => _markDirty(),
                                ),
                              ),
                              (
                                1,
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Semantics(
                                    label: 'UF brasileira',
                                    container: true,
                                    explicitChildNodes: true,
                                    child: _statePicker(),
                                  ),
                                ),
                              ),
                              (
                                1,
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
                              ),
                            ]),
                          ],
                        ),
                        _FormSection(
                          title: 'Modalidades',
                          children: <Widget>[
                            Semantics(
                              // Give keyboard users a direct focus target for the choice set.
                              child: Focus(
                                focusNode: _fieldFocusNodes['sports'],
                                child: Semantics(
                                  label: 'Modalidades disponíveis',
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
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
                                                    _sports = <String>[
                                                      ..._sports,
                                                      sport,
                                                    ];
                                                    _primarySport ??= sport;
                                                  } else {
                                                    _sports = _sports
                                                        .where(
                                                          (item) =>
                                                              item != sport,
                                                        )
                                                        .toList();
                                                    if (_primarySport ==
                                                        sport) {
                                                      _primarySport =
                                                          _sports.isEmpty
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
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
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
                            ),
                          ],
                        ),
                        _FormSection(
                          title: 'Acesso',
                          children: <Widget>[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 330,
                                child: DropdownButtonFormField<String>(
                                  key: const ValueKey<String>(
                                    'place-accessType',
                                  ),
                                  initialValue: _accessType,
                                  focusNode: _fieldFocusNodes['accessType'],
                                  decoration: InputDecoration(
                                    labelText: 'Tipo de local',
                                    hintText: 'Selecione',
                                    helperText: _accessType == null
                                        ? 'Este local ainda não tem tipo informado.'
                                        : null,
                                    errorText: _draftError('accessType'),
                                  ),
                                  items: const <DropdownMenuItem<String>>[
                                    DropdownMenuItem<String>(
                                      value: 'public',
                                      child: Text('Público'),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'private',
                                      child: Text('Privado'),
                                    ),
                                  ],
                                  onChanged: _submitting
                                      ? null
                                      : (value) => setState(() {
                                          _accessType = value;
                                          _dirty = true;
                                        }),
                                ),
                              ),
                            ),
                            if (_accessType == 'private') ...<Widget>[
                              const SizedBox(height: 20),
                              _textField(
                                controller: _contactPhone,
                                label: 'Telefone para contato',
                                keyName: 'contactPhone',
                                keyboardType: TextInputType.phone,
                                maxLength: 15,
                                inputFormatters: <TextInputFormatter>[
                                  AdminBrazilianPhoneInputFormatter(),
                                ],
                                onChanged: (_) => _markDirty(),
                              ),
                            ],
                          ],
                        ),
                        _FormSection(
                          title: 'Localização',
                          description: 'Toque no mapa para posicionar o marcador ou edite latitude e longitude.',
                          children: <Widget>[
                            _buildMapPicker(draft),
                            const SizedBox(height: 16),
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
                            if (draft.isFarFromTaquara) ...<Widget>[
                              const SizedBox(height: 12),
                              const _FormMessage(
                                message: 'Este ponto está a mais de 50 km de Taquara. Confira se as coordenadas estão corretas; o aviso não impede o cadastro.',
                                isWarning: true,
                              ),
                            ],
                          ],
                        ),
                        _FormSection(
                          title: 'Imagens',
                          description: 'A primeira imagem será usada como capa. Você pode adicionar até 8 fotos.',
                          children: <Widget>[
                            for (var index = 0; index < _images.length; index++)
                              _imageEditor(index),
                            if (_draftError('images') case final message?)
                              _InlineFieldError(message: message),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: _submitting || _images.length >= 8
                                    ? null
                                    : _addImage,
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
                                label: Text(
                                  'Adicionar imagem (${_images.length}/8)',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _isCreating
                                    ? 'Cadastrar inativo'
                                    : 'Salvar alterações',
                              ),
                            ),
                            if (!_isCreating)
                              OutlinedButton.icon(
                                onPressed: _submitting || _dirty
                                    ? null
                                    : () => _changeStatus(
                                        widget.place!.isActive
                                            ? 'inactive'
                                            : 'active',
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
                            TextButton(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageEditor(int index) {
    final image = _images[index];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Chip(
                avatar: Icon(
                  index == 0 ? Icons.photo : Icons.photo_outlined,
                  size: 16,
                ),
                label: Text(index == 0 ? 'Capa' : 'Imagem ${index + 1}'),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Mover para cima',
                onPressed: _submitting || index == 0
                    ? null
                    : () => _moveImage(index, -1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Mover para baixo',
                onPressed: _submitting || index == _images.length - 1
                    ? null
                    : () => _moveImage(index, 1),
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'Remover imagem',
                onPressed: _submitting || _images.length == 1
                    ? null
                    : () => _removeImage(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _textField(
            controller: image.url,
            label: 'URL HTTPS da imagem',
            keyName: index == 0 ? 'imageUrl' : 'imageUrl-$index',
            maxLength: 2048,
            maxWidth: double.infinity,
            keyboardType: TextInputType.url,
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: 8),
          _textField(
            controller: image.source,
            label: 'Fonte da imagem (opcional)',
            keyName: 'imageSource-$index',
            maxLength: 200,
            maxWidth: double.infinity,
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _ImagePreview(url: image.url.text),
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
    double maxWidth = 680,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
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

class _PlaceImageInput {
  _PlaceImageInput({String url = '', String? source})
    : url = TextEditingController(text: url),
      source = TextEditingController(text: source ?? '');

  final TextEditingController url;
  final TextEditingController source;

  void dispose() {
    url.dispose();
    source.dispose();
  }
}

class AdminBrazilianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limitedDigits = digits.length > 11 ? digits.substring(0, 11) : digits;
    final beforeCursor = newValue.text
        .substring(
          0,
          newValue.selection.extentOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(RegExp(r'\D'), '')
        .length
        .clamp(0, limitedDigits.length);
    final formatted = formatAdminBrazilianPhone(limitedDigits);
    var cursorOffset = 0;
    var seenDigits = 0;
    while (cursorOffset < formatted.length && seenDigits < beforeCursor) {
      if (RegExp(r'\d').hasMatch(formatted[cursorOffset])) seenDigits++;
      cursorOffset++;
    }
    while (cursorOffset < formatted.length &&
        !RegExp(r'\d').hasMatch(formatted[cursorOffset])) {
      cursorOffset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
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
    child: _Notice(
      color: AdminColors.errorContainer,
      foreground: AdminColors.onErrorContainer,
      icon: Icons.error_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Revise os campos destacados:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ...errors.values.map((error) => Text('• $error')),
        ],
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
  Widget build(BuildContext context) => _Notice(
    color: isWarning
        ? AdminColors.warningContainer
        : AdminColors.errorContainer,
    foreground: isWarning
        ? AdminColors.onWarningContainer
        : AdminColors.onErrorContainer,
    icon: isWarning ? Icons.warning_amber_outlined : Icons.info_outline,
    trailing: actionLabel != null && onAction != null
        ? TextButton(onPressed: onAction, child: Text(actionLabel!))
        : null,
    child: Text(message),
  );
}

class _CachedPlaceBanner extends StatelessWidget {
  const _CachedPlaceBanner();

  @override
  Widget build(BuildContext context) => const _Notice(
    color: AdminColors.warningContainer,
    foreground: AdminColors.onWarningContainer,
    icon: Icons.cloud_off_outlined,
    child: Text(
      'Dados carregados do cache. Conecte-se para salvar alterações.',
    ),
  );
}

/// Aviso em faixa colorida, acima do conteúdo a que se refere.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: color,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foreground),
                child: child,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    ),
  );
}

/// Grupo de campos do formulário, com título.
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.children,
    this.description,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleLarge),
              if (description != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Campos lado a lado (com pesos), empilhados em telas estreitas.
class _FieldRow extends StatelessWidget {
  const _FieldRow(this.fields);

  final List<(int, Widget)> fields;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[for (final (_, field) in fields) field],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (index, (flex, field)) in fields.indexed) ...<Widget>[
            if (index > 0) const SizedBox(width: 12),
            Expanded(flex: flex, child: field),
          ],
        ],
      );
    },
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
