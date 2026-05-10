import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_geo.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/skill_level.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../data/datasources/in_memory_events_store.dart';
import '../providers/events_providers.dart';
import '../widgets/event_form_field.dart';

/// Tela "3 Criar evento" — formulário com campos obrigatórios (RF07).
class CreateEventPage extends ConsumerStatefulWidget {
  const CreateEventPage({super.key});

  @override
  ConsumerState<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends ConsumerState<CreateEventPage> {
  final _sportCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  final _participantsCtrl = TextEditingController();
  final _spotsCtrl = TextEditingController();

  Sport? _sport;
  SkillLevel? _skill;
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void dispose() {
    _sportCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _skillCtrl.dispose();
    _participantsCtrl.dispose();
    _spotsCtrl.dispose();
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
              EventFormField(
                hint: AppStrings.eventSkillLevel,
                controller: _skillCtrl,
                readOnly: true,
                onTap: _pickSkill,
              ),
              EventFormField(
                hint: AppStrings.eventParticipants,
                controller: _participantsCtrl,
              ),
              EventFormField(
                hint: AppStrings.eventVacancies,
                controller: _spotsCtrl,
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(4, 8, 0, 8),
                  child: Text(
                    AppStrings.eventLocation,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 140,
                  child: AbsorbPointer(
                    child: FlutterMap(
                      options: const MapOptions(
                        initialCenter: AppGeo.taquaraCenter,
                        initialZoom: 13.5,
                        interactionOptions: InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'br.com.compy.mvp',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: AppStrings.eventCreate,
                onPressed: _canSubmit() ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canSubmit() =>
      _sport != null &&
      _date != null &&
      _time != null &&
      _skill != null &&
      int.tryParse(_spotsCtrl.text) != null;

  Future<void> _pickSport() async {
    final picked = await showModalBottomSheet<Sport>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final s in Sport.values)
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

  Future<void> _submit() async {
    final dateTime = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    final spots = int.parse(_spotsCtrl.text);
    final draft = Event(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Evento de ${_sport!.label}',
      sport: _sport!,
      location: 'Taquara',
      coordinates: const LatLng(-29.6500, -50.7800),
      dateTime: dateTime,
      skillLevel: _skill!,
      totalSpots: spots,
      remainingSpots: spots,
      bannerUrl: _sport!.banner,
      creator: InMemoryEventsStore.currentUser,
    );
    await ref.read(createEventProvider).call(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Evento criado!'), backgroundColor: AppColors.success),
    );
    context.go(AppRoutes.events);
  }
}
