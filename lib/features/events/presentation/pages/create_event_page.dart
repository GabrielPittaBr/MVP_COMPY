import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_geo.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/clock_providers.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/event_place_snapshot.dart';
import '../../../../shared/models/event_status.dart';
import '../../../../shared/models/skill_level.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/custom_sport_marker.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../maps/domain/repositories/places_repository.dart';
import '../../../maps/presentation/providers/maps_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/events_providers.dart';
import '../../domain/repositories/events_repository.dart';
import '../widgets/event_form_field.dart';

/// Tela "4 Criar evento" — formulário com campos obrigatórios (RF07).
///
/// Ordem de preenchimento: depois do Título, o Local é a primeira
/// informação selecionada, pois ele determina quais esportes estão
/// disponíveis (pins curados pela equipe — ver [SportPlace]).
class CreateEventPage extends ConsumerStatefulWidget {
  const CreateEventPage({this.initialPlaceId, super.key});

  /// Local já escolhido no mapa (id de [SportPlace]) — pula o primeiro
  /// passo do formulário. Nulo quando a tela é aberta pela aba "Criar".
  final String? initialPlaceId;

  @override
  ConsumerState<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends ConsumerState<CreateEventPage> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _sportCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  /// Input do "Outro". Vive junto da página (e não dentro do diálogo)
  /// porque descartá-lo assim que o showDialog retorna estoura o
  /// `_dependents.isEmpty`: a rota ainda está animando a saída com o
  /// TextField escutando o controller.
  final _customDurationCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  final _participantsCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  /// Teto do título — cabe na AppBar da tela de detalhes e no card da lista.
  static const int _titleMaxLength = 50;

  /// Teto da descrição escrita pelo criador (D2: campo opcional, sem
  /// texto automático de fallback).
  static const int _descriptionMaxLength = 300;

  /// Opções fixas do seletor de duração, em minutos.
  static const List<int> _durationOptions = <int>[30, 60, 90, 120, 180];

  /// Valor devolvido pelo bottom sheet quando o criador escolhe "Outro"
  /// — não é uma duração, só sinaliza que o input deve abrir.
  static const int _customDurationOption = -1;

  /// Limites do input de "Outro" (15min a 12h). O teto é compartilhado
  /// com as listas, que contam com ele para saber até quando um evento
  /// pode estar aberto.
  static const int _minDurationMinutes = 15;
  static const int _maxDurationMinutes = kMaxEventDurationMinutes;

  SportPlace? _location;
  Sport? _sport;
  SkillLevel? _skill;
  DateTime? _date;
  TimeOfDay? _time;

  /// Obrigatória, mas já vem preenchida (D8) — por isso fica fora do
  /// _canSubmit() e nunca chega nula ao _submit().
  int _durationMinutes = Event.defaultDurationMinutes;
  bool _isLoading = false;
  String? _placeMessage;

  @override
  void initState() {
    super.initState();
    _durationCtrl.text = DurationFormat.short(_durationMinutes);
    // O nº de participantes habilita/desabilita o botão "Criar evento";
    // sem isso o _canSubmit() só seria reavaliado nos setState dos pickers.
    _participantsCtrl.addListener(_onTypedFieldChanged);
    final placeId = widget.initialPlaceId;
    if (placeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveInitialPlace(placeId);
      });
    }
  }

  @override
  void didUpdateWidget(CreateEventPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A aba "Criar" é um branch do shell: o State sobrevive à navegação,
    // então chegar de novo pelo mapa reconstrói o widget sem passar pelo
    // initState. Sem isto, o segundo local escolhido no mapa seria
    // ignorado.
    if (oldWidget.initialPlaceId != widget.initialPlaceId &&
        widget.initialPlaceId != null) {
      _resolveInitialPlace(widget.initialPlaceId!);
    }
  }

  /// Resolve no repository o local escolhido no mapa; nunca consulta fixture
  /// estática para preencher um novo Evento Esportivo.
  Future<void> _resolveInitialPlace(String placeId) async {
    try {
      final lookup = await ref.read(placeByIdProvider(placeId).future);
      if (!mounted) return;
      final place = lookup.place;
      if (place == null || place.status != PlaceStatus.active) {
        setState(() {
          _placeMessage = place == null
              ? (lookup.isFromCache
                  ? 'Reconecte-se para carregar o local escolhido.'
                  : 'Local não encontrado. Escolha um local ativo.')
              : 'Este local está inativo. Escolha outro local ativo.';
        });
        return;
      }
      _selectLocation(place);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _placeMessage = 'Não foi possível carregar o local. Tente novamente.';
      });
    }
  }

  void _retryPlacesLoad() {
    ref.invalidate(placesProvider);
    final placeId = widget.initialPlaceId;
    if (placeId != null && _location == null) {
      ref.invalidate(placeByIdProvider(placeId));
      _resolveInitialPlace(placeId);
    }
  }

  void _onTypedFieldChanged() => setState(() {});

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _sportCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _durationCtrl.dispose();
    _customDurationCtrl.dispose();
    _skillCtrl.dispose();
    _participantsCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesProvider);
    final activePlaces =
        placesAsync.valueOrNull?.places ?? const <SportPlace>[];
    ref.listen<AsyncValue<PlacesStreamResult>>(placesProvider,
        (previous, next) {
      next.whenData(_reconcileSelectedPlace);
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.eventCreateTitle),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: <Widget>[
              // Título opcional — nome do evento nas listas e na tela de
              // detalhes. A primeira letra é garantida maiúscula no
              // _submit(); o teclado já sobe em maiúscula via
              // textCapitalization.
              EventFormField(
                hint: AppStrings.eventTitleHint,
                controller: _titleCtrl,
                maxLength: _titleMaxLength,
                textCapitalization: TextCapitalization.sentences,
              ),
              // 1) Local — primeira seleção do formulário.
              EventFormField(
                hint: AppStrings.eventSelectLocation,
                controller: _locationCtrl,
                readOnly: true,
                onTap: placesAsync.isLoading && !placesAsync.hasValue
                    ? null
                    : () => _pickLocation(activePlaces),
                suffix: const Icon(Icons.location_on_outlined),
              ),
              if (placesAsync.isLoading && !placesAsync.hasValue)
                const _PlaceStatusNotice(
                  message: 'Carregando locais ativos…',
                ),
              if (_placeMessage != null || placesAsync.hasError)
                _PlaceStatusNotice(
                  message: _placeMessage ??
                      'Não foi possível carregar os locais. Verifique a conexão.',
                  onRetry: placesAsync.hasError ||
                          (widget.initialPlaceId != null && _location == null)
                      ? _retryPlacesLoad
                      : null,
                ),
              if (placesAsync.valueOrNull?.isFromCache == true)
                const _PlaceStatusNotice(
                  message: 'Locais salvos neste dispositivo (offline).',
                ),
              if (placesAsync.valueOrNull != null && activePlaces.isEmpty)
                const _PlaceStatusNotice(
                  message: 'Nenhum local ativo disponível.',
                ),
              _LocationMapPreview(location: _location),
              const SizedBox(height: 12),
              // 2) Esporte — restrito aos praticáveis no local escolhido.
              EventFormField(
                hint: AppStrings.eventSelectSport,
                controller: _sportCtrl,
                readOnly: true,
                onTap: _pickSport,
              ),
              EventFormField(
                hint: AppStrings.eventDate,
                controller: _dateCtrl,
                readOnly: true,
                onTap: _pickDate,
              ),
              EventFormField(
                hint: AppStrings.eventTime,
                controller: _timeCtrl,
                readOnly: true,
                onTap: _pickTime,
              ),
              if (_startsInPast())
                const _PlaceStatusNotice(message: AppStrings.eventStartInPast),
              // Duração — pré-selecionada em 1h, trocável no seletor.
              EventFormField(
                hint: AppStrings.eventDuration,
                controller: _durationCtrl,
                readOnly: true,
                onTap: _pickDuration,
                suffix: const Icon(Icons.schedule),
              ),
              EventFormField(
                hint: AppStrings.eventSkillLevel,
                controller: _skillCtrl,
                readOnly: true,
                onTap: _pickSkill,
              ),
              EventFormField(
                hint: AppStrings.eventParticipantsNumber,
                controller: _participantsCtrl,
                keyboardType: TextInputType.number,
              ),
              // Descrição opcional — o placeholder é quem ensina o que
              // escrever, já que o campo não tem rótulo próprio.
              EventFormField(
                hint: AppStrings.eventDescriptionHint,
                controller: _descriptionCtrl,
                keyboardType: TextInputType.multiline,
                maxLines: 4,
                maxLength: _descriptionMaxLength,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: _isLoading ? 'Criando...' : AppStrings.eventCreate,
                onPressed: (_canSubmit() && !_isLoading) ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canSubmit() {
    return _location?.status == PlaceStatus.active &&
        _sport != null &&
        _date != null &&
        _time != null &&
        !_startsInPast() &&
        _skill != null &&
        (int.tryParse(_participantsCtrl.text) ?? 0) >= 2;
  }

  /// Início escolhido, ou nulo enquanto falta a data ou o horário.
  DateTime? get _startsAt {
    final date = _date;
    final time = _time;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// O seletor de data já impede os dias passados, mas não um horário que
  /// já passou no dia de hoje — e um evento criado assim nasceria ao vivo
  /// ou já encerrado (tarefa 14). O minuto atual ainda vale: o horário não
  /// tem segundos, e começar agora é legítimo.
  bool _startsInPast() {
    final startsAt = _startsAt;
    if (startsAt == null) return false;
    final now = ref.read(clockProvider)();
    final thisMinute =
        DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return startsAt.isBefore(thisMinute);
  }

  Future<void> _pickLocation(List<SportPlace> activePlaces) async {
    final picked = await showModalBottomSheet<SportPlace>(
      context: context,
      // Locais ativos do Firestore em um seletor rolável, inclusive em
      // janelas baixas e dispositivos na horizontal.
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            if (activePlaces.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum local ativo disponível.'),
              )
            else
              for (final loc in activePlaces)
                ListTile(
                  leading:
                      const Icon(Icons.location_on, color: AppColors.error),
                  title: Text(loc.name),
                  subtitle: Text(loc.address.formatted),
                  onTap: () => Navigator.of(context).pop(loc),
                ),
          ],
        ),
      ),
    );
    if (picked != null) _selectLocation(picked);
  }

  void _selectLocation(SportPlace place) {
    setState(() {
      _location = place;
      _locationCtrl.text = '${place.name} — ${place.address.city}';
      _placeMessage = null;
      // Descarta esporte incompatível com o novo local.
      if (_sport != null && !place.allowedSports.contains(_sport)) {
        _sport = null;
        _sportCtrl.clear();
      }
    });
  }

  void _reconcileSelectedPlace(PlacesStreamResult result) {
    if (result.isFromCache) return;
    final selected = _location;
    if (selected == null) return;
    SportPlace? latest;
    for (final candidate in result.places) {
      if (candidate.id == selected.id) {
        latest = candidate;
        break;
      }
    }
    if (latest == null) {
      _invalidateLocation('O local foi desativado. Escolha outro local ativo.');
      return;
    }
    final sportsChanged = latest.sports
            .toSet()
            .difference(selected.sports.toSet())
            .isNotEmpty ||
        selected.sports.toSet().difference(latest.sports.toSet()).isNotEmpty;
    if (latest.name != selected.name ||
        latest.address != selected.address ||
        latest.coordinates != selected.coordinates ||
        sportsChanged) {
      _invalidateLocation(
        'O local mudou. Revise e selecione novamente antes de criar o evento.',
      );
    } else if (latest != selected) {
      setState(() => _location = latest);
    }
  }

  void _invalidateLocation(String message) {
    if (!mounted) return;
    setState(() {
      _location = null;
      _sport = null;
      _locationCtrl.clear();
      _sportCtrl.clear();
      _placeMessage = message;
    });
  }

  Future<void> _pickSport() async {
    final location = _location;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.eventSelectLocationFirst)),
      );
      return;
    }
    final picked = await showModalBottomSheet<Sport>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            // Apenas esportes praticáveis no local selecionado.
            for (final s in location.allowedSports)
              ListTile(
                leading: Icon(s.icon, color: s.color),
                title: Text(s.label),
                onTap: () => Navigator.of(context).pop(s),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _sport = picked;
        _sportCtrl.text = picked.label;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(ref.read(clockProvider)()),
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _timeCtrl.text = picked.format(context);
      });
    }
  }

  Future<void> _pickDuration() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final minutes in _durationOptions)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(DurationFormat.short(minutes)),
                trailing: minutes == _durationMinutes
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(minutes),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(AppStrings.eventDurationOther),
              onTap: () => Navigator.of(context).pop(_customDurationOption),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;

    final minutes =
        picked == _customDurationOption ? await _askCustomDuration() : picked;
    if (minutes == null || !mounted) return;

    setState(() {
      _durationMinutes = minutes;
      _durationCtrl.text = DurationFormat.short(minutes);
    });
  }

  /// Input livre do "Outro". Devolve `null` quando o criador cancela ou
  /// digita um valor fora dos limites (aí o campo mantém o anterior).
  Future<int?> _askCustomDuration() async {
    _customDurationCtrl.clear();
    final typed = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.eventDurationCustomTitle),
        content: TextField(
          controller: _customDurationCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: AppStrings.eventDurationCustomHint,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(AppStrings.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(int.tryParse(_customDurationCtrl.text.trim())),
            child: const Text(AppStrings.commonConfirm),
          ),
        ],
      ),
    );

    if (!mounted) return null;
    if (typed == null) return null;
    if (typed < _minDurationMinutes || typed > _maxDurationMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.eventDurationCustomInvalid)),
      );
      return null;
    }
    return typed;
  }

  Future<void> _pickSkill() async {
    final picked = await showModalBottomSheet<SkillLevel>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final lvl in SkillLevel.values)
              ListTile(
                title: Text(lvl.label),
                onTap: () => Navigator.of(context).pop(lvl),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _skill = picked;
        _skillCtrl.text = picked.label;
      });
    }
  }

  /// Garante a inicial maiúscula mesmo em teclado físico, onde o
  /// [TextCapitalization] do campo não tem efeito.
  String _capitalizeFirst(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  Future<void> _submit() async {
    // O relógio pode ter passado do horário escolhido enquanto o resto do
    // formulário era preenchido; o botão só reavalia ao reconstruir.
    if (_startsInPast()) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.eventStartInPast)),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final authUser = ref.read(authStateProvider).valueOrNull ??
          await ref.read(authStateProvider.future);
      if (authUser == null) {
        throw StateError('Você precisa estar logado para criar um evento.');
      }
      // UserSummary real do usuário logado (users/{uid} no Firestore).
      final creator = await ref.read(currentUserSummaryProvider.future);

      final dateTime = _startsAt!;
      final location = _location!;
      final sport = _sport!;
      final totalSpots = int.parse(_participantsCtrl.text);
      final typedTitle = _titleCtrl.text.trim();

      final draft = Event(
        id: '', // Firestore gerará o ID
        // Título é opcional: em branco cai no nome padrão da modalidade,
        // já que a lista e a AppBar de detalhes precisam de um rótulo.
        title: typedTitle.isEmpty
            ? 'Partida de ${sport.label.toLowerCase()}'
            : _capitalizeFirst(typedTitle),
        sport: sport,
        location: '${location.name}, ${location.address.city}',
        coordinates: location.coordinates,
        placeId: location.id,
        placeSnapshot: EventPlaceSnapshot.fromPlace(location),
        dateTime: dateTime,
        durationMinutes: _durationMinutes,
        skillLevel: _skill!,
        totalSpots: totalSpots,
        // O criador já ocupa uma vaga.
        remainingSpots: totalSpots - 1,
        bannerUrl: sport.banner,
        creator: creator,
        description: _descriptionCtrl.text.trim(),
        participants: <UserSummary>[creator],
      );

      await ref.read(createEventProvider).call(draft, selectedPlace: location);
      // Recarrega as seções para o novo evento já aparecer em "Criados por
      // mim" (e em "Participando", já que o criador ocupa uma vaga).
      invalidateEventLists(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evento criado!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go(AppRoutes.events);
    } on EventPlaceChangedException {
      _invalidateLocation(
        'O local mudou. Revise e selecione novamente; os outros dados foram preservados.',
      );
    } on EventPlaceUnavailableException {
      _invalidateLocation(
        'O local foi desativado. Escolha outro local ativo; os outros dados foram preservados.',
      );
    } on EventPlaceSportUnsupportedException {
      _invalidateLocation(
        'A modalidade não é mais oferecida pelo local. Revise sua seleção.',
      );
    } on EventCreationOfflineException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reconecte-se para criar o evento. Seus dados foram preservados.',
            ),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final offline = const <String>{'unavailable', 'network-request-failed'}
          .contains(error.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(offline
              ? 'Reconecte-se para criar o evento. Seus dados foram preservados.'
              : 'Erro ao criar evento: ${error.message ?? error.code}'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar evento: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _PlaceStatusNotice extends StatelessWidget {
  const _PlaceStatusNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
                if (onRetry != null)
                  TextButton(
                      onPressed: onRetry,
                      child: const Text('Tentar novamente')),
              ],
            ),
          ),
        ),
      );
}

/// Mapa com o pin fixo do local selecionado. Antes da seleção, mostra
/// Taquara centralizada sem marcador.
class _LocationMapPreview extends StatelessWidget {
  const _LocationMapPreview({required this.location});

  final SportPlace? location;

  @override
  Widget build(BuildContext context) {
    final center = location?.coordinates ?? AppGeo.taquaraCenter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 140,
        child: AbsorbPointer(
          child: FlutterMap(
            // Recria o mapa quando o local muda, recentralizando no pin.
            key: ValueKey<String?>(location?.id),
            options: MapOptions(
              initialCenter: center,
              initialZoom: location != null ? 15.5 : 13.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'br.com.compy.mvp',
              ),
              if (location != null)
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: location!.coordinates,
                      // Mesmas medidas e âncora do pin não selecionado do
                      // mapa (RF04) — o local tem que ser reconhecível
                      // igual nas duas telas.
                      width: 40,
                      height: 50,
                      alignment: Alignment.topCenter,
                      child: CustomSportMarker(
                        sport: location!.primarySport,
                        selected: false,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
