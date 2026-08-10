import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/sport_select_tile.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';

/// Escolha de esportes favoritos — último passo do cadastro.
///
/// Mora no feature de perfil, não no de auth, porque é perfil que ela edita:
/// a escrita vai por `ProfileRepository` e a mesma tela é reaproveitada na
/// edição a partir da aba Perfil.
///
/// **Pular grava lista vazia, e isso é de propósito.** O que marca o
/// onboarding como concluído é o campo passar a existir em `users/{uid}`, não
/// a lista ter itens. Se o "pular" não gravasse nada, o guard do router
/// devolveria o usuário para cá na abertura seguinte, para sempre.
class FavoriteSportsPage extends ConsumerStatefulWidget {
  const FavoriteSportsPage({super.key});

  @override
  ConsumerState<FavoriteSportsPage> createState() => _FavoriteSportsPageState();
}

class _FavoriteSportsPageState extends ConsumerState<FavoriteSportsPage> {
  Set<Sport> _selected = <Sport>{};

  /// Sem isto, uma reemissão do perfil (invalidação, refresh) apagaria o que
  /// o usuário acabou de marcar.
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();

    // Perfil já em cache: aproveita sem esperar. É o caso da edição, aberta a
    // partir da aba Perfil, que já leu o documento.
    final UserProfile? cached = ref.read(currentProfileProvider).valueOrNull;
    if (cached != null) {
      _selected = cached.favoriteSports.toSet();
      _prefilled = true;
      return;
    }

    ref.listenManual<AsyncValue<UserProfile>>(currentProfileProvider,
        (_, AsyncValue<UserProfile> next) {
      final UserProfile? profile = next.valueOrNull;
      if (_prefilled || profile == null || !mounted) return;
      setState(() {
        _selected = profile.favoriteSports.toSet();
        _prefilled = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSaving = ref.watch(favoriteSportsControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                AppStrings.onboardingSportsTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.onboardingSportsHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: <Widget>[
                      for (final Sport sport in Sport.values)
                        SportSelectTile(
                          sport: sport,
                          isSelected: _selected.contains(sport),
                          onTap: isSaving ? () {} : () => _toggle(sport),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: isSaving
                    ? AppStrings.authLoading
                    : AppStrings.onboardingSportsContinue,
                // Continuar exige ao menos um esporte; quem não quer escolher
                // usa "pular", que é um caminho explícito e não um atalho.
                onPressed: isSaving || _selected.isEmpty
                    ? null
                    : () => _save(_selected.toList()),
              ),
              TextButton(
                onPressed: isSaving ? null : () => _save(const <Sport>[]),
                child: const Text(
                  AppStrings.onboardingSportsSkip,
                  style: TextStyle(color: AppColors.onSurfaceMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(Sport sport) {
    setState(() {
      if (!_selected.remove(sport)) _selected.add(sport);
    });
  }

  Future<void> _save(List<Sport> sports) async {
    final bool saved = await ref
        .read(favoriteSportsControllerProvider.notifier)
        .save(sports);
    if (!mounted) return;

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.onboardingSportsSaveError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    context.go(AppRoutes.home);
  }
}
