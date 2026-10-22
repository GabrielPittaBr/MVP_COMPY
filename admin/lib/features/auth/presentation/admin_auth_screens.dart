import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/admin_strings.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/theme/admin_court.dart';
import 'admin_auth_feature.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({required this.controller, super.key});

  final AdminAuthController controller;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.controller.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _AdminAuthLayout(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _AuthHeading(
                title: AdminStrings.loginTitle,
                body: AdminStrings.loginBody,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.username],
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o e-mail.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const <String>[AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Senha'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Informe a senha.' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (widget.controller.loginError case final message?) ...<Widget>[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.error_outline, size: 20, color: colors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: widget.controller.isSigningIn ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: widget.controller.isSigningIn
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminUnauthorizedScreen extends StatelessWidget {
  const AdminUnauthorizedScreen({required this.controller, super.key});

  final AdminAuthController controller;

  @override
  Widget build(BuildContext context) {
    return _AdminAuthLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.lock_outline,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 20),
          const _AuthHeading(
            title: AdminStrings.unauthorizedTitle,
            body: AdminStrings.unauthorizedBody,
          ),
          const SizedBox(height: 28),
          FilledButton.tonal(
            onPressed: () {
              controller.returnToLogin();
              context.go('/login');
            },
            child: const Text('Voltar ao login'),
          ),
        ],
      ),
    );
  }
}

class _AuthHeading extends StatelessWidget {
  const _AuthHeading({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          body,
          style: textTheme.bodyLarge?.copyWith(
            color: AdminColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Quadra com o nome do produto ao lado (ou acima, em telas estreitas) do
/// conteúdo de acesso.
class _AdminAuthLayout extends StatelessWidget {
  const _AdminAuthLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: child,
        ),
      ),
    );

    // A quadra ao lado já cabe em tablets; empilhada, empurraria o formulário.
    if (MediaQuery.sizeOf(context).width >= 720) {
      return Scaffold(
        backgroundColor: AdminColors.surface,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Expanded(
              flex: 5,
              child: AdminCourtSurface(
                horizontal: true,
                child: Center(child: AdminWordmark(size: 72, centered: true)),
              ),
            ),
            Expanded(flex: 4, child: content),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AdminColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(
            height: 176,
            child: AdminCourtSurface(
              horizontal: true,
              child: SafeArea(
                bottom: false,
                child: Center(child: AdminWordmark(size: 44, centered: true)),
              ),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
