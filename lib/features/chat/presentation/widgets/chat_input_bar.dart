import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

/// Barra inferior de digitação. Os ícones de imagem e voz são
/// placeholders — RF14 (multimídia) tem prioridade baixa no MVP.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({required this.onSend, super.key});

  final ValueChanged<String> onSend;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: AppStrings.chatHint,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.image_outlined),
                        color: AppColors.onSurfaceMuted,
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.mic_none),
                        color: AppColors.onSurfaceMuted,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _send,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
