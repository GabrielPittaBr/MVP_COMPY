import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Insígnia / conquista de gamificação (RF08).
class SportBadge extends Equatable {
  const SportBadge({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;

  @override
  List<Object?> get props => <Object?>[id, label, icon, color];
}
