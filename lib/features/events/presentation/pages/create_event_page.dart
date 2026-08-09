import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_geo.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/skill_level.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/custom_sport_marker.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/events_providers.dart';
import '../widgets/event_form_field.dart';

/// Tela "4 Criar evento" — formulário com campos obrigatórios (RF07).
///
/// Ordem de preenchimento: depois do Título, o Local é a primeira
/// informação selecionada, pois ele determina quais esportes estão
/// disponíveis (pins curados pela equipe — ver [SportPlace]).
class CreateEventPage extends ConsumerStatefulWidget {
  const CreateEventPage({super.key});

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

  /// Limites do input de "Outro" (15min a 12h).
  static const int _minDurationMinutes = 15;
  static const int _maxDurationMinutes = 720;

  SportPlace? _location;
  Sport? _sport;
  SkillLevel? _skill;
  DateTime? _date;
  TimeOfDay? _time;

  /// Obrigatória, mas já vem preenchida (D8) — por isso fica fora do
  /// _canSubmit() e nunca chega nula ao _submit().
  int _durationMinutes = Event.defaultDurationMinutes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _durationCtrl.text = DurationFormat.short(_durationMinutes);
    // O nº de participantes habilita/desabilita o botão "Criar evento";
    // sem isso o _canSubmit() só seria reavaliado nos setState dos pickers.
    _participantsCtrl.addListener(_onTypedFieldChanged);
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
                onTap: _pickLocation,
                suffix: const Icon(Icons.location_on_outlined),
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

  bool _canSubmit() =>
      _location != null &&
      _sport != null &&
      _date != null &&
      _time != null &&
      _skill != null &&
      (int.tryParse(_participantsCtrl.text) ?? 0) >= 2;

  Future<void> _pickLocation() async {
    final picked = await showModalBottomSheet<SportPlace>(
      context: context,
      // Mesmo catálogo curado que alimenta os pins do mapa.
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final loc in SportPlace.all)
              ListTile(
                leading: const Icon(Icons.location_on, color: AppColors.error),
                title: Text(loc.name),
                subtitle: Text(loc.city),
                onTap: () => Navigator.of(context).pop(loc),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _location = picked;
        _locationCtrl.text = '${picked.name} — ${picked.city}';
        // Descarta esporte incompatível com o novo local.
        if (_sport != null && !picked.allowedSports.contains(_sport)) {
          _sport = null;
          _sportCtrl.clear();
        }
      });
    }
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
    final now = DateTime.now();
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
      initialTime: TimeOfDay.now(),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
    setState(() => _isLoading = true);

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) {
        throw StateError('Você precisa estar logado para criar um evento.');
      }
      // UserSummary real do usuário logado (users/{uid} no Firestore).
      final creator = await ref.read(currentUserSummaryProvider.future);

      final dateTime = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _time!.hour,
        _time!.minute,
      );
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
        location: '${location.name}, ${location.city}',
        coordinates: location.coordinates,
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

      await ref.read(createEventProvider).call(draft);
      // Recarrega a lista paginada para o novo evento aparecer.
      ref.invalidate(paginatedEventsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evento criado!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go(AppRoutes.events);
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
