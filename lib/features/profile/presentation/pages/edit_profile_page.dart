import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/avatar_picker.dart';
import '../../../../shared/widgets/rounded_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';

/// Edição do nome e da biografia; a foto continua gravada na hora.
///
/// O campo de username aparece apagado em vez de ausente de propósito: quem
/// abre "Editar perfil" vem procurar exatamente por ele, e uma tela sem o
/// campo parece quebrada. Apagado, com o aviso embaixo, responde a pergunta.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();
  String _originalName = '';
  String _originalBio = '';
  bool _allowPop = false;
  bool _requestingSave = false;

  bool get _dirty =>
      _prefilled &&
      (_nameCtrl.text.trim() != _originalName || _bioCtrl.text != _originalBio);

  void _fill(UserProfile profile) {
    _usernameCtrl.text = profile.summary.handle;
    _nameCtrl.text = _originalName = profile.summary.name;
    _bioCtrl.text = _originalBio = profile.bio;
    _prefilled = true;
  }

  /// Vive na página, e não dentro do diálogo, pelo mesmo motivo do
  /// `_customDurationCtrl` da criação de evento: descartá-lo assim que o
  /// `showDialog` retorna estoura enquanto a rota ainda anima a saída.
  final TextEditingController _passwordCtrl = TextEditingController();

  /// Sem isto, uma reemissão do perfil sobrescreveria o campo já preenchido.
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();

    // Chegando pela aba Perfil o documento já está em cache — é o caso normal.
    final UserProfile? cached = ref.read(currentProfileProvider).valueOrNull;
    if (cached != null) {
      _fill(cached);
      return;
    }

    ref.listenManual<AsyncValue<UserProfile>>(currentProfileProvider,
        (_, AsyncValue<UserProfile> next) {
      final UserProfile? profile = next.valueOrNull;
      if (_prefilled || profile == null || !mounted) return;
      setState(() {
        _fill(profile);
      });
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sucesso não precisa de tratamento: o controller fecha com `null`, o
    // guard do router vê que não há mais usuário e leva para /login sozinho.
    ref.listen<AsyncValue<Object?>>(authControllerProvider,
        (_, AsyncValue<Object?> next) {
      next.whenOrNull(
        error: (Object error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(firebaseAuthErrorMessage(error)),
              backgroundColor: AppColors.error,
            ),
          );
        },
      );
    });

    final bool isDeleting = ref.watch(authControllerProvider).isLoading;
    final bool isSavingPhoto = ref.watch(avatarControllerProvider).isLoading;
    final bool isSaving = ref.watch(profileDetailsControllerProvider).isLoading;
    final UserSummary? me =
        ref.watch(currentProfileProvider).valueOrNull?.summary;

    return PopScope(
      canPop: (!isSaving && !_requestingSave && !_dirty) || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _dirty && !isSaving && !_requestingSave) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.profileEdit)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              if (me != null) ...<Widget>[
                AvatarPicker(
                  name: me.name,
                  photoUrl: me.avatarUrl,
                  busy: isSavingPhoto,
                  onPicked: (Uint8List jpeg) => _savePhoto(me, jpeg),
                  onRemoved: () => _savePhoto(me, null),
                ),
                const SizedBox(height: 24),
              ],
              const _Label(AppStrings.profileNameLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                readOnly: isSaving,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: AppStrings.profileNameLabel,
                  errorText: _prefilled && _nameCtrl.text.trim().isEmpty
                      ? AppStrings.profileNameRequired
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              const _Label(AppStrings.profileBioLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _bioCtrl,
                maxLength: 160,
                maxLines: 4,
                readOnly: isSaving,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(hintText: AppStrings.profileBioHint),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      !_dirty || isSaving || _requestingSave || isDeleting
                          ? null
                          : _saveDetails,
                  child: Text(isSaving
                      ? AppStrings.authLoading
                      : AppStrings.profileSaveChanges),
                ),
              ),
              const SizedBox(height: 24),
              const _Label(AppStrings.authUsernameField),
              const SizedBox(height: 8),
              IgnorePointer(
                child: Opacity(
                  opacity: 0.5,
                  child: RoundedTextField(
                    hint: AppStrings.authUsernameField,
                    controller: _usernameCtrl,
                    readOnly: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const _Hint(AppStrings.profileUsernameLocked),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              const _Label(AppStrings.profileAccountSection),
              const SizedBox(height: 8),
              const _Hint(AppStrings.profileDeleteAccountHint),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isDeleting ? null : _deleteAccount,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    isDeleting
                        ? AppStrings.authLoading
                        : AppStrings.profileDeleteAccount,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDetails() async {
    if (!_dirty ||
        _requestingSave ||
        ref.read(profileDetailsControllerProvider).isLoading) {
      return;
    }
    final name = _nameCtrl.text.trim();
    final bio = _bioCtrl.text;
    if (name.isEmpty || name.length > 60 || bio.length > 160) {
      setState(() {});
      return;
    }
    setState(() => _requestingSave = true);
    String? uid = ref.read(authControllerProvider).valueOrNull?.uid ??
        ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null && kUseFirebaseRepos) {
      try {
        uid = (await ref.read(authStateProvider.future))?.uid;
      } catch (_) {
        // A mensagem de falha abaixo permite tentar de novo.
      }
    }
    if (!kUseFirebaseRepos) {
      uid ??= ref.read(currentProfileProvider).valueOrNull?.summary.id;
    }
    if (!mounted) return;
    if (uid == null || uid.isEmpty) {
      setState(() => _requestingSave = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(AppStrings.profileSaveError),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    final saved = await ref
        .read(profileDetailsControllerProvider.notifier)
        .save(uid, name: name, bio: bio);
    if (!mounted) return;
    setState(() => _requestingSave = false);
    if (saved) {
      setState(() {
        _nameCtrl.text = _originalName = name;
        _originalBio = bio;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          saved ? AppStrings.profileSaveSuccess : AppStrings.profileSaveError),
      backgroundColor: saved ? null : AppColors.error,
    ));
  }

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.profileDiscardTitle),
        content: const Text(AppStrings.profileDiscardBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(AppStrings.profileContinueEditing)),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(AppStrings.profileDiscard)),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) context.pop();
    }
  }

  /// [jpeg] `null` remove a foto. Sem botão Salvar: grava assim que escolhe.
  Future<void> _savePhoto(UserSummary me, Uint8List? jpeg) async {
    final bool saved =
        await ref.read(avatarControllerProvider.notifier).save(me, jpeg);
    if (saved || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.photoSaveError),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final bool needsPassword =
        ref.read(authRepositoryProvider).signedInWithPassword();
    _passwordCtrl.clear();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(AppStrings.profileDeleteAccountTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(AppStrings.profileDeleteAccountBody),
            const SizedBox(height: 16),
            if (needsPassword)
              TextField(
                controller: _passwordCtrl,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: AppStrings.profileDeleteAccountPasswordHint,
                ),
              )
            else
              const _Hint(AppStrings.profileDeleteAccountGoogleHint),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              AppStrings.profileDeleteAccountConfirm,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final String password = _passwordCtrl.text;
    if (needsPassword && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.profileDeleteAccountPasswordEmpty),
        ),
      );
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .deleteAccount(password: needsPassword ? password : null);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: AppColors.onSurfaceMuted,
      ),
    );
  }
}
