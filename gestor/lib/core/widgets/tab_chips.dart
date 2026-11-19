import 'package:flutter/material.dart';

/// Abas simples em botões: cada parte de uma tela longa fica sozinha, para
/// não juntar conteúdo demais (pedido de simplificar o desenho).
class TabChips extends StatelessWidget {
  const TabChips({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<(String, IconData)> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final (i, (label, icon)) in tabs.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          ChoiceChip(
            selected: i == selected,
            showCheckmark: false,
            avatar: Icon(icon, size: 18),
            label: Text(label),
            onSelected: (_) => onSelected(i),
          ),
        ],
      ],
    ),
  );
}
