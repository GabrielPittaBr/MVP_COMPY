import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout.dart';
import '../../../core/shell/gestor_shell.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/theme/gestor_theme.dart';
import '../../../core/widgets/common.dart';
import '../../auth/presentation/session_controller.dart';
import '../../venue/presentation/venue_controller.dart';

/// "Mais" do celular: o que não cabe na barra inferior.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final owner = session?.role.managesVenue ?? false;
    final items = [
      for (final d in destinations)
        if (d.route != '/hoje' &&
            d.route != '/agenda' &&
            d.route != '/livres' &&
            (owner || !d.owner))
          d,
    ];
    return PageScaffold(
      title: 'Mais',
      subtitle: ref.watch(venueProvider).name,
      children: [
        Card(
          child: ListTile(
            leading: InitialsAvatar(session?.name ?? ''),
            title: Text(
              session?.name ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(session?.role.label ?? ''),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (final (i, d) in items.indexed) ...[
                if (i > 0) const Divider(indent: 56),
                ListTile(
                  leading: Icon(d.icon, color: GestorColors.primary),
                  title: Text(d.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(d.route),
                ),
              ],
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.swap_horiz,
                  color: GestorColors.primary,
                ),
                title: Text(
                  owner ? 'Ver como Atendente' : 'Ver como Proprietário',
                ),
                subtitle: const Text('Demonstração: troca o papel sem sair'),
                onTap: () => switchRole(context, ref),
              ),
              const Divider(indent: 56),
              ListTile(
                leading: const Icon(Icons.logout, color: GestorColors.error),
                title: const Text('Sair'),
                onTap: () => signOut(context, ref),
              ),
            ],
          ),
        ),
        const Center(child: CompyBadge(color: GestorColors.onSurfaceVariant)),
      ],
    );
  }
}

/// Plano e período gratuito (RF-P90).
class PlanPage extends ConsumerWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courts = ref.watch(venueProvider).activeCourts.length;
    final tiers = [
      ('1 quadra', 'R\$ 49', courts == 1),
      ('2 a 3 quadras', 'R\$ 99', courts >= 2 && courts <= 3),
      ('4 a 5 quadras', 'R\$ 149', courts >= 4 && courts <= 5),
      ('Mais de 5', 'R\$ 149 + R\$ 20 por quadra', courts > 5),
    ];
    return PageScaffold(
      title: 'Plano',
      subtitle: 'Só o Proprietário vê esta página.',
      back: '/mais',
      children: [
        Card(
          color: GestorColors.primary,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PLANO PRO · PERÍODO GRATUITO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Grátis até 30/04/2027',
                  style: TextStyle(
                    fontFamily: GestorTheme.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Faltam 162 dias. Depois, com $courts quadras ativas, o '
                  'plano fica em R\$ 149 por mês. Avisamos 15 dias antes.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: 0.2,
                    minHeight: 8,
                    color: const Color(0xFF34D399),
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
        ),
        SectionCard(
          title: 'Preço do Pro por mês',
          gap: 4,
          children: [
            for (final (label, price, current) in tiers)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: current ? GestorColors.primaryContainer : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: current
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      price,
                      style: TextStyle(
                        fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (current) ...[
                      const SizedBox(width: 8),
                      const StatusPill(
                        label: 'o seu',
                        background: GestorColors.primary,
                        foreground: Colors.white,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        const NoteBox(
          'A Vitrine é grátis e mostra o perfil do local no app. O Pro libera '
          'agenda, solicitações, horários livres e resultados. Até o COMPY ter '
          'CNPJ, a mensalidade é paga por Pix ou boleto, fora do painel.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () =>
                showDone(context, 'A equipe do COMPY responde pelo WhatsApp.'),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Falar com o COMPY'),
          ),
        ),
      ],
    );
  }
}

/// Ajuda (RF-P93): falar com o COMPY, perguntas frequentes e problemas.
class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  static const _faq = [
    (
      'Como confirmo uma solicitação do app?',
      'Na tela Hoje, toque em Confirmar no cartão da solicitação. Se não '
          'responder no prazo, ela vence e o horário volta a ficar livre.',
    ),
    (
      'O que é um horário livre?',
      'É um horário vazio que vocês publicam no app COMPY, com desconto se '
          'quiserem. Ele sai do app sozinho quando é reservado ou começa.',
    ),
    (
      'Já uso outro sistema de agenda. Preciso passar tudo para cá?',
      'Não. Publique só os horários que quiser oferecer no COMPY e use '
          '"Marcar como ocupado" para o que foi vendido no outro sistema.',
    ),
    (
      'Como deixo o painel na tela inicial do celular?',
      'No Android, abra o menu do Chrome e toque em "Instalar app". No '
          'iPhone, toque em Compartilhar e depois em "Adicionar à Tela de '
          'Início". Assim os avisos chegam como os de um app.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageScaffold(
    title: 'Ajuda',
    subtitle: 'A equipe do COMPY responde em horário comercial.',
    back: '/mais',
    children: [
      Card(
        color: GestorColors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.chat_outlined, color: GestorColors.secondary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Falar com o COMPY pelo WhatsApp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: GestorColors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Dúvida no meio do atendimento? Mande uma mensagem.',
                style: TextStyle(color: GestorColors.onSecondaryContainer),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: GestorColors.secondary,
                ),
                onPressed: () => showDone(
                  context,
                  'Na versão final, abre a conversa com o COMPY no WhatsApp.',
                ),
                child: const Text('Abrir o WhatsApp'),
              ),
            ],
          ),
        ),
      ),
      SectionCard(
        title: 'Perguntas frequentes',
        gap: 0,
        children: [
          for (final (q, a) in _faq)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(
                  q,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: [
                  Text(
                    a,
                    style: const TextStyle(
                      color: GestorColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () async {
            final sent = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Reportar um problema'),
                content: const SizedBox(
                  width: 420,
                  child: TextField(
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Conte o que aconteceu e em qual tela.',
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Voltar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Enviar'),
                  ),
                ],
              ),
            );
            if (sent == true && context.mounted) {
              showDone(context, 'Recebemos. Obrigado por avisar!');
            }
          },
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('Reportar um problema'),
        ),
      ),
      if (!isDesktop(context))
        const Center(child: CompyBadge(color: GestorColors.onSurfaceVariant)),
    ],
  );
}
