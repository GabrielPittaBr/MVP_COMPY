import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/username_rules.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/chat_providers.dart';
import '../widgets/peer_avatar.dart';

/// Busca por handle para iniciar uma conversa.
///
/// Escolher alguém abre a conversa existente ou cria uma nova — o id é
/// determinístico, então os dois caminhos terminam no mesmo documento.
class NewConversationPage extends ConsumerStatefulWidget {
  const NewConversationPage({super.key});

  @override
  ConsumerState<NewConversationPage> createState() =>
      _NewConversationPageState();
}

class _NewConversationPageState extends ConsumerState<NewConversationPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  bool _opening = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(UserSummary peer) async {
    // Sem trava, tocar duas vezes dispara duas criações — o id determinístico
    // evita a conversa duplicada, mas não a navegação em dobro.
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final me = await ref.read(currentUserSummaryProvider.future);
      final conversationId = await ref
          .read(openConversationProvider)
          .call(me: me, peer: peer);

      // A conversa nova ainda não está na lista nem no cache da sala.
      ref.invalidate(paginatedConversationsProvider);
      ref.invalidate(conversationProvider(conversationId));

      if (!mounted) return;
      context.go('${AppRoutes.chat}/$conversationId');
    } catch (_) {
      if (!mounted) return;
      setState(() => _opening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.chatOpenConversationError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(userSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.chatNewConversation)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              // Mesmas regras do cadastro: handle é minúsculo e sem acento,
              // então digitar "João" não pode virar uma busca que nunca acha.
              inputFormatters: UsernameRules.inputFormatters,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: AppStrings.chatSearchHandleHint,
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
          ),
          if (_opening) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: results.when(
              data: (users) {
                if (_query.trim().length < 2) {
                  return const _Notice(text: AppStrings.chatSearchPrompt);
                }
                if (users.isEmpty) {
                  return const _Notice(text: AppStrings.chatSearchEmpty);
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 76),
                  itemBuilder: (context, i) {
                    final user = users[i];
                    return ListTile(
                      onTap: _opening ? null : () => _open(user),
                      leading: PeerAvatar(peer: user, radius: 24),
                      title: Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        user.handle,
                        style: const TextStyle(color: AppColors.onSurfaceMuted),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const _Notice(text: AppStrings.chatSearchError),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.onSurfaceMuted),
        ),
      ),
    );
  }
}
