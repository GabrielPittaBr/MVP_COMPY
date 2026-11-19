import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout.dart';
import '../../../core/theme/court_painter.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/common.dart';
import '../../venue/domain/venue.dart';
import '../../venue/presentation/venue_controller.dart';
import 'session_controller.dart';

/// Entrar pelo convite (tela 1), já com o tema e as iniciais do local.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  var _withEmail = false;

  void _enter(Role role) {
    ref.read(sessionProvider.notifier).signIn(role);
    context.go('/hoje');
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(venueProvider);
    final desktop = isDesktop(context);
    final brand = CourtSurface(
      style: venue.theme.court,
      portrait: desktop && MediaQuery.sizeOf(context).aspectRatio < 1.6,
      inset: 16,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Monogram(name: venue.name, size: desktop ? 112 : 88),
              const SizedBox(height: 16),
              Text(
                venue.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: GestorTheme.display,
                  fontWeight: FontWeight.w600,
                  fontSize: desktop ? 48 : 36,
                  height: 1.05,
                  color: venue.theme.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Painel do Local',
                style: TextStyle(fontSize: 16, color: venue.theme.ink2),
              ),
            ],
          ),
        ),
      ),
    );
    final form = _Form(
      venueName: venue.name,
      withEmail: _withEmail,
      onEmail: () => setState(() => _withEmail = true),
      onEnter: _enter,
    );
    if (desktop) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: brand),
            Expanded(
              child: ColoredBox(
                color: GestorColors.surface,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: form,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: GestorColors.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(height: 300, child: brand),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: form,
          ),
        ],
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.venueName,
    required this.withEmail,
    required this.onEmail,
    required this.onEnter,
  });

  final String venueName;
  final bool withEmail;
  final VoidCallback onEmail;
  final ValueChanged<Role> onEnter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Você recebeu um convite para a equipe',
          style: text.headlineSmall?.copyWith(fontSize: 30),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: GestorColors.onSurfaceVariant,
            ),
            children: [
              const TextSpan(text: 'Carlos Mendes convidou você para ser '),
              const TextSpan(
                text: 'Atendente',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: GestorColors.onSurface,
                ),
              ),
              TextSpan(
                text:
                    ' da $venueName. Entre com a sua própria conta para '
                    'aceitar.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const NoteBox(
          'O convite vale até qui., 26/11 e só pode ser usado uma vez.',
          icon: Icons.schedule,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => onEnter(Role.atendente),
          icon: const _GoogleMark(),
          label: const Text('Continuar com Google'),
        ),
        const SizedBox(height: 12),
        if (!withEmail)
          OutlinedButton.icon(
            onPressed: onEmail,
            icon: const Icon(Icons.mail_outline),
            label: const Text('Entrar com e-mail e senha'),
          )
        else ...[
          const TextField(
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: 12),
          TextField(
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Senha'),
            onSubmitted: (_) => onEnter(Role.atendente),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => onEnter(Role.atendente),
            child: const Text('Entrar'),
          ),
        ],
        const SizedBox(height: 28),
        _DemoBox(onEnter: onEnter),
        const SizedBox(height: 28),
        const CompyBadge(color: GestorColors.onSurfaceVariant),
        const SizedBox(height: 8),
        const Text(
          'Ao entrar, você aceita os termos do parceiro e a política de '
          'privacidade.',
          style: TextStyle(fontSize: 12, color: GestorColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Caixa da demonstração: os dados são fictícios e qualquer botão entra.
class _DemoBox extends StatelessWidget {
  const _DemoBox({required this.onEnter});

  final ValueChanged<Role> onEnter;

  @override
  Widget build(BuildContext context) => DashedBorder(
    radius: 12,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DEMONSTRAÇÃO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: GestorColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tudo aqui é fictício e nada é salvo. Escolha com que papel '
            'quer ver o painel:',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => onEnter(Role.atendente),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Ana, Atendente'),
              ),
              OutlinedButton.icon(
                onPressed: () => onEnter(Role.proprietario),
                icon: const Icon(Icons.key_outlined),
                label: const Text('Carlos, Proprietário'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// "G" simples, sem usar a marca do Google como imagem.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: const Text(
      'G',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: GestorColors.primary,
        fontSize: 14,
        height: 1,
      ),
    ),
  );
}
