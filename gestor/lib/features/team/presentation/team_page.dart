import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout.dart';
import '../../../core/shell/page_scaffold.dart';
import '../../../core/theme/gestor_colors.dart';
import '../../../core/widgets/common.dart';
import '../../auth/presentation/session_controller.dart';
import '../../venue/domain/venue.dart';
import 'team_controller.dart';

/// Equipe e convites (RF-P02 e RF-P04). A tabela completa de permissões
/// fica recolhida; à vista, um resumo de cada papel.
class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamProvider);
    final me = ref.watch(sessionProvider)?.name;
    final desktop = isDesktop(context);
    final people = SectionCard(
      title: 'Pessoas com acesso',
      trailing: StatusPill(
        label: '${team.where((m) => !m.pending).length}',
        background: GestorColors.primaryContainer,
        foreground: GestorColors.primary,
      ),
      gap: 4,
      children: [
        for (final (i, m) in team.indexed) ...[
          if (i > 0) const Divider(),
          _MemberRow(member: m, you: m.name == me),
        ],
      ],
    );
    final roles = SectionCard(
      title: 'O que cada papel pode fazer',
      children: [
        const _RoleSummary(
          icon: Icons.badge_outlined,
          role: 'Atendente',
          text:
              'Cuida do dia a dia: agenda, reservas, solicitações do app, '
              'bloqueios e horários livres. Dá desconto até o limite.',
        ),
        const _RoleSummary(
          icon: Icons.manage_accounts_outlined,
          role: 'Gerente',
          text:
              'Tudo do Atendente, mais quadras, preços, perfil e resultados. '
              'Não mexe na equipe nem no plano.',
          later: true,
        ),
        const _RoleSummary(
          icon: Icons.key_outlined,
          role: 'Proprietário',
          text:
              'Pode tudo, inclusive convidar e remover pessoas e ver o plano.',
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Ver a tabela completa',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: GestorColors.primary,
              ),
            ),
            children: [_PermissionsTable()],
          ),
        ),
      ],
    );
    final security = SectionCard(
      title: 'Segurança',
      children: [
        const Text(
          'Tirou alguém da equipe ou perdeu o celular? Encerre o acesso em '
          'todos os aparelhos.',
          style: TextStyle(color: GestorColors.onSurfaceVariant),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await _confirm(
              context,
              'Sair de todos os aparelhos?',
              'Todas as pessoas da equipe precisam entrar de novo, cada uma '
                  'com a própria conta.',
              'Sair de todos',
            );
            if (ok && context.mounted) {
              showDone(
                context,
                'Pronto. Todos os aparelhos foram desconectados.',
              );
            }
          },
          icon: const Icon(Icons.devices_other_outlined),
          label: const Text('Sair de todos os aparelhos'),
        ),
        TextButton(
          onPressed: () => showDone(
            context,
            'A transferência pede a confirmação de quem recebe a propriedade.',
          ),
          child: const Text('Transferir a propriedade do local'),
        ),
      ],
    );
    return PageScaffold(
      title: 'Equipe',
      subtitle:
          'Cada pessoa entra com a própria conta. Quem sai da equipe perde o '
          'acesso na hora.',
      mobileSubtitle: 'Cada pessoa com a própria conta',
      back: '/mais',
      actions: [
        FilledButton.icon(
          onPressed: () => openForm(context, ref, const InviteForm()),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Convidar pessoa'),
        ),
      ],
      children: desktop
          ? [
              LayoutBuilder(
                builder: (context, box) => box.maxWidth < 900
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          people,
                          const SizedBox(height: 20),
                          roles,
                          const SizedBox(height: 20),
                          security,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                people,
                                const SizedBox(height: 20),
                                roles,
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(width: 340, child: security),
                        ],
                      ),
              ),
            ]
          : [
              FilledButton.icon(
                onPressed: () => openForm(context, ref, const InviteForm()),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Convidar pessoa'),
              ),
              people,
              roles,
              security,
            ],
    );
  }
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String body,
  String action, {
  bool danger = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 400, child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: GestorColors.error)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.member, required this.you});

  final Member member;
  final bool you;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(teamProvider.notifier);
    final rolePill = member.pending
        ? const StatusPill(
            label: 'Convite pendente',
            background: GestorColors.warningContainer,
            foreground: GestorColors.onWarningContainer,
          )
        : StatusPill(
            label: member.role.label,
            background: member.role == Role.proprietario
                ? GestorColors.primaryContainer
                : GestorColors.surfaceContainer,
            foreground: member.role == Role.proprietario
                ? GestorColors.primary
                : GestorColors.onSurface,
            dot: member.role == Role.proprietario
                ? GestorColors.primary
                : GestorColors.secondary,
          );
    final actions = <Widget>[
      if (member.pending) ...[
        TextButton(
          onPressed: () {
            Clipboard.setData(
              const ClipboardData(
                text: 'https://compy-tcc-gestor.web.app/convite/AE7K2Q',
              ),
            );
            showDone(context, 'Link do convite copiado.');
          },
          child: const Text('Copiar link'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: GestorColors.error),
          onPressed: () {
            notifier.remove(member);
            showDone(context, 'Convite revogado. O link não funciona mais.');
          },
          child: const Text('Revogar'),
        ),
      ] else if (member.role != Role.proprietario) ...[
        TextButton(
          onPressed: () async {
            final ok = await _confirm(
              context,
              'Tornar ${member.name} Proprietário?',
              'O Proprietário pode tudo, inclusive mexer na equipe e no plano.',
              'Mudar papel',
            );
            if (ok && context.mounted) {
              notifier.changeRole(member, Role.proprietario);
              showDone(context, '${member.name} agora é Proprietário.');
            }
          },
          child: const Text('Mudar papel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: GestorColors.error),
          onPressed: () async {
            final ok = await _confirm(
              context,
              'Remover ${member.name}?',
              '${member.name.split(' ').first} perde o acesso ao painel na '
                  'hora. O que já foi feito continua no histórico.',
              'Remover',
              danger: true,
            );
            if (ok && context.mounted) {
              notifier.remove(member);
              showDone(context, '${member.name} saiu da equipe.');
            }
          },
          child: const Text('Remover'),
        ),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InitialsAvatar(member.name),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (you)
                            const Text(
                              'você',
                              style: TextStyle(
                                color: GestorColors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        member.detail,
                        style: const TextStyle(
                          fontSize: 13,
                          color: GestorColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [rolePill, const SizedBox(width: 4), ...actions],
          ),
        ],
      ),
    );
  }
}

class _RoleSummary extends StatelessWidget {
  const _RoleSummary({
    required this.icon,
    required this.role,
    required this.text,
    this.later = false,
  });

  final IconData icon;
  final String role;
  final String text;
  final bool later;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: GestorColors.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(role, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (later) ...[const SizedBox(width: 8), const LaterPill()],
              ],
            ),
            Text(
              text,
              style: const TextStyle(color: GestorColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PermissionsTable extends StatelessWidget {
  const _PermissionsTable();

  static const _rows = <(String, String, String, String)>[
    ('Ver a agenda e as solicitações', 'sim', 'sim', 'sim'),
    ('Criar, mover e cancelar reservas', 'sim', 'sim', 'sim'),
    ('Confirmar ou recusar solicitações', 'sim', 'sim', 'sim'),
    ('Bloquear e marcar como ocupado', 'sim', 'sim', 'sim'),
    ('Publicar horários livres e eventos', 'sim', 'sim', 'sim'),
    ('Dar desconto', 'qualquer', 'até o limite', 'até o limite'),
    ('Editar perfil, fotos, logo e tema', 'sim', 'sim', 'não'),
    ('Mudar quadras, preços e regras', 'sim', 'sim', 'não'),
    ('Ver resultados e valores do mês', 'sim', 'sim', 'não'),
    ('Convidar, remover e mudar papéis', 'sim', 'não', 'não'),
    ('Ver o plano e a cobrança', 'sim', 'não', 'não'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget cell(String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: v == 'sim'
          ? const Icon(Icons.check, size: 18, color: GestorColors.secondary)
          : v == 'não'
          ? const Icon(Icons.remove, size: 18, color: GestorColors.outline)
          : Text(
              v,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
    );
    Widget head(String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        v,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 520),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.4),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
            3: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            horizontalInside: BorderSide(color: GestorColors.outlineVariant),
          ),
          children: [
            TableRow(
              children: [
                head('Ação'),
                head('Proprietário'),
                head('Gerente (2ª versão)'),
                head('Atendente'),
              ],
            ),
            for (final (action, p, g, a) in _rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(action, style: const TextStyle(fontSize: 13)),
                  ),
                  cell(p),
                  cell(g),
                  cell(a),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Convidar pessoa: o convite vale 7 dias e só pode ser usado uma vez.
class InviteForm extends ConsumerStatefulWidget {
  const InviteForm({super.key});

  @override
  ConsumerState<InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends ConsumerState<InviteForm> {
  var _role = Role.atendente;
  var _generated = false;

  static const _link = 'compy-tcc-gestor.web.app/convite/AE7K2Q';

  @override
  Widget build(BuildContext context) => FormFrame(
    title: 'Convidar pessoa',
    actions: [
      if (!_generated)
        FilledButton.icon(
          onPressed: () {
            ref.read(teamProvider.notifier).invite(_role);
            setState(() => _generated = true);
          },
          icon: const Icon(Icons.link),
          label: const Text('Gerar convite'),
        )
      else
        OutlinedButton(
          onPressed: () => closeForm(context, ref),
          child: const Text('Pronto'),
        ),
    ],
    children: [
      const Text(
        'Papel',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: GestorColors.onSurfaceVariant,
        ),
      ),
      for (final (role, text) in const [
        (
          Role.atendente,
          'Cuida de horários e reservas, dentro dos preços e regras.',
        ),
        (Role.gerente, 'Chega na 2ª versão do painel.'),
        (Role.proprietario, 'Pode tudo, inclusive mexer na equipe e no plano.'),
      ])
        _RoleOption(
          role: role,
          text: text,
          selected: _role == role,
          enabled: role != Role.gerente && !_generated,
          onTap: () => setState(() => _role = role),
        ),
      if (_generated) ...[
        const Text(
          'Link do convite',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: GestorColors.onSurfaceVariant,
          ),
        ),
        Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(
            color: GestorColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GestorColors.outline),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  _link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Copiar link',
                onPressed: () {
                  Clipboard.setData(
                    const ClipboardData(text: 'https://$_link'),
                  );
                  showDone(context, 'Link copiado. Mande por WhatsApp.');
                },
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
        ),
        NoteBox(
          'Vale até qui., 26/11 e só pode ser usado uma vez. A pessoa abre o '
          'link, entra com a própria conta e já cai no painel como '
          '${_role.label}.',
          icon: Icons.schedule,
        ),
      ],
    ],
  );
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Role role;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled || selected ? 1 : 0.55,
    child: Material(
      color: selected ? GestorColors.primaryContainer : GestorColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? GestorColors.primary : GestorColors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        color: GestorColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: GestorColors.primary),
              if (role == Role.gerente) const LaterPill(),
            ],
          ),
        ),
      ),
    ),
  );
}
