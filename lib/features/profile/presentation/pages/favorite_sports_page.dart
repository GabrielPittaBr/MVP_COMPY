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

/// Os dois contextos em que a tela aparece.
enum FavoriteSportsMode {
  /// Último passo do cadastro: pede ao menos um esporte, oferece pular e
  /// segue para a Home.
  onboarding,

  /// Aberta pela aba Perfil: já dá para voltar atrás, então não há o que
  /// pular, e limpar tudo é uma edição legítima.
  edit,
}

/// Escolha de esportes favoritos — último passo do cadastro, e a tela de
/// edição da seção correspondente no perfil.
///
/// Mora no feature de perfil, não no de auth, porque é perfil que ela edita:
/// a escrita vai por `ProfileRepository` e a mesma tela serve os dois
/// contextos de [FavoriteSportsMode].
///
/// **Pular grava lista vazia, e isso é de propósito.** O que marca o
/// onboarding como concluído é o campo passar a existir em `users/{uid}`, não
/// a lista ter itens. Se o "pular" não gravasse nada, o guard do router
/// devolveria o usuário para cá na abertura seguinte, para sempre.
class FavoriteSportsPage extends ConsumerStatefulWidget {
  const FavoriteSportsPage({
    this.mode = FavoriteSportsMode.onboarding,
    super.key,
  });

  final FavoriteSportsMode mode;

  bool get _isOnboarding => mode == FavoriteSportsMode.onboarding;

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

    final bool isOnboarding = widget._isOnboarding;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isOnboarding
          ? null
          : AppBar(title: const Text(AppStrings.onboardingSportsEditTitle)),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, isOnboarding ? 32 : 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (isOnboarding) ...<Widget>[
                Text(
                  AppStrings.onboardingSportsTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                isOnboarding
                    ? AppStrings.onboardingSportsHint
                    : AppStrings.onboardingSportsEditHint,
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
                          onTap: isSaving ? null : () => _toggle(sport),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: isSaving
                    ? AppStrings.authLoading
                    : isOnboarding
                        ? AppStrings.onboardingSportsContinue
                        : AppStrings.onboardingSportsSave,
                // No cadastro, continuar exige ao menos um esporte: quem não
                // quer escolher usa "pular", que é um caminho explícito e não
                // um atalho. Na edição, deixar sem nenhum é uma escolha
                // legítima — e não desfaz o onboarding, porque o que o guard
                // olha é o campo existir.
                onPressed: isSaving || (isOnboarding && _selected.isEmpty)
                    ? null
                    : () => _save(_selected.toList()),
              ),
              if (isOnboarding)
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

    // No cadastro o destino é a Home; na edição, de volta ao perfil.
    if (widget._isOnboarding) {
      context.go(AppRoutes.home);
    } else {
      context.pop();
    }
  }
}
