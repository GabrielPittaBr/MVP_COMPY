import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';

/// Tela de login — ponto de entrada do fluxo de autenticação.
///
/// Layout (de cima para baixo):
/// 1. Carrossel de fotos esportivas (PageView com indicadores).
/// 2. Logo centralizada.
/// 3. Tagline.
/// 4. Botões: "Entrar com email", "Entrar com Google", "Criar Conta".
/// 5. Rodapé de privacidade.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Formulário de e-mail (expansível)
  bool _showEmailForm = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      next.whenOrNull(
        error: (e, _) {
          final msg = firebaseAuthErrorMessage(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.error,
            ),
          );
        },
      );
    });

    final bool isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ── 1. Carrossel ─────────────────────────────────────────────
              _Carousel(
                pageController: _pageController,
                currentPage: _currentPage,
                onPageChanged: (i) => setState(() => _currentPage = i),
              ),

              const SizedBox(height: 32),

              // ── 2. Logo ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Image.asset(
                  AppAssets.logoAsset,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const _LogoFallback(),
                ),
              ),

              const SizedBox(height: 16),

              // ── 3. Tagline ────────────────────────────────────────────────
              Text(
                AppStrings.authTagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
              ),

              const SizedBox(height: 24),

              // ── 4. Botões ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Entrar com e-mail
                    PrimaryButton(
                      label: AppStrings.authLoginWithEmail,
                      onPressed: isLoading
                          ? null
                          : () => setState(() => _showEmailForm = !_showEmailForm),
                      icon: Icons.email_outlined,
                    ),

                    // Formulário de e-mail (expansível)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _showEmailForm
                          ? _EmailForm(
                              formKey: _formKey,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              isLoading: isLoading,
                              onSubmit: _submitEmailLogin,
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 12),

                    // Entrar com Google
                    _GoogleButton(
                      isLoading: isLoading,
                      onPressed: _signInWithGoogle,
                    ),

                    const SizedBox(height: 8),

                    // Criar Conta (link)
                    Center(
                      child: TextButton(
                        onPressed: isLoading ? null : () => context.push(AppRoutes.signup),
                        child: Text(
                          AppStrings.authCreateAccount,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                decoration: TextDecoration.underline,
                                color: AppColors.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 5. Rodapé privacidade ─────────────────────────────────────
              _PrivacyFooter(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitEmailLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sub-widgets privados
// ──────────────────────────────────────────────────────────────────────────────

class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
  });

  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    const List<String> images = AppAssets.loginCarousel;
    return Column(
      children: <Widget>[
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemCount: images.length,
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, __) => Container(color: AppColors.surfaceMuted),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.surfaceMuted,
                  child: const Icon(Icons.sports, size: 48, color: AppColors.onSurfaceMuted),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(
            images.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: currentPage == i ? 14 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: currentPage == i
                    ? AppColors.primary
                    : AppColors.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.sports_soccer, size: 56, color: AppColors.secondary),
        Text(
          'COMPY',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
        ),
        Text(
          'Come Play.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondary,
              ),
        ),
      ],
    );
  }
}

class _EmailForm extends StatelessWidget {
  const _EmailForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: <Widget>[
            AuthTextField(
              hint: AppStrings.authEmail,
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return AppStrings.authErrorEmailInvalid;
                if (!v.contains('@')) return AppStrings.authErrorEmailInvalid;
                return null;
              },
            ),
            const SizedBox(height: 10),
            AuthTextField(
              hint: AppStrings.authPassword,
              controller: passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              validator: (v) {
                if (v == null || v.length < 6) return AppStrings.authErrorPasswordShort;
                return null;
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : onSubmit,
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(AppStrings.authLoginWithEmail),  // ignore: prefer_const_constructors
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceMuted,
          foregroundColor: AppColors.onSurface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Ícone Google usando cores oficiais (sem pacote extra)
            const _GoogleIcon(),
            const SizedBox(width: 10),
            Text(
              AppStrings.authLoginWithGoogle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Fundo branco
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );

    // Letras G estilizadas via 4 arcos coloridos (simplificado)
    final Paint paint = Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.35;
    const Rect rect = Rect.fromLTWH(2, 2, 16, 16);

    paint.color = const Color(0xFF4285F4); // azul
    canvas.drawArc(rect, -0.5, 1.6, false, paint);
    paint.color = const Color(0xFFEA4335); // vermelho
    canvas.drawArc(rect, 1.1, 1.1, false, paint);
    paint.color = const Color(0xFFFBBC05); // amarelo
    canvas.drawArc(rect, 2.2, 0.9, false, paint);
    paint.color = const Color(0xFF34A853); // verde
    canvas.drawArc(rect, 3.1, 0.9, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PrivacyFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
          children: <InlineSpan>[
            TextSpan(text: '${AppStrings.authPrivacyPrefix} '),
            TextSpan(
              text: AppStrings.authPrivacyPolicy,
              style: const TextStyle(
                decoration: TextDecoration.underline,
                color: AppColors.onSurface,
              ),
              recognizer: TapGestureRecognizer()..onTap = () {
                // TODO: abrir URL da política de privacidade
              },
            ),
          ],
        ),
      ),
    );
  }
}
