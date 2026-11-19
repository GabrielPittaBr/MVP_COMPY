import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/gestor_colors.dart';

/// Rótulo acima de cada campo, como nas telas.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: GestorColors.onSurfaceVariant,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Campo com rótulo em cima.
class Field extends StatelessWidget {
  const Field(this.label, this.child, {this.trailing, super.key});

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FieldLabel(label, trailing: trailing),
      child,
    ],
  );
}

/// Escolha entre poucas opções, em botões grandes (alvos de 48 px).
class Choices<T> extends StatelessWidget {
  const Choices({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.label,
    this.icon,
    this.enabled,
    super.key,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T)? label;
  final IconData? Function(T)? icon;
  final bool Function(T)? enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in options)
        ChoiceChip(
          selected: option == selected,
          showCheckmark: icon == null,
          avatar: icon?.call(option) == null
              ? null
              : Icon(icon!(option), size: 18),
          label: Text(label?.call(option) ?? '$option'),
          onSelected: (enabled?.call(option) ?? true)
              ? (_) => onSelected(option)
              : null,
        ),
    ],
  );
}

/// Dia entre hoje e daqui a [days] dias (antecedência máxima de 14 dias).
class DayField extends StatelessWidget {
  const DayField({
    required this.value,
    required this.onChanged,
    this.days = 14,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int days;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    items: [
      for (var d = 0; d <= days; d++)
        DropdownMenuItem(
          value: d,
          child: Text(
            d <= 1 ? '${friendlyDate(d)}, ${shortDate(d)}' : shortDate(d),
          ),
        ),
    ],
    onChanged: (d) => onChanged(d ?? value),
  );
}

/// Hora cheia ou meia hora entre [from] e [to] (em minutos).
class TimeField extends StatelessWidget {
  const TimeField({
    required this.value,
    required this.onChanged,
    required this.from,
    required this.to,
    this.step = 60,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int from;
  final int to;
  final int step;

  @override
  Widget build(BuildContext context) {
    final options = [for (var m = from; m <= to; m += step) m];
    final current = options.contains(value) ? value : options.first;
    return DropdownButtonFormField<int>(
      key: ValueKey('$from-$to-$current'),
      initialValue: current,
      isExpanded: true,
      items: [
        for (final m in options)
          DropdownMenuItem(value: m, child: Text(hhmm(m))),
      ],
      onChanged: (m) => onChanged(m ?? current),
    );
  }
}

/// Mensagem de disponibilidade: verde quando pode, vermelha quando não.
class AvailabilityNote extends StatelessWidget {
  const AvailabilityNote({required this.ok, required this.text, super.key});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: ok ? GestorColors.secondaryContainer : GestorColors.errorContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          size: 20,
          color: ok ? GestorColors.secondary : GestorColors.error,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: ok
                  ? GestorColors.onSecondaryContainer
                  : GestorColors.onErrorContainer,
            ),
          ),
        ),
      ],
    ),
  );
}
