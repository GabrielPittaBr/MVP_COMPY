import 'package:equatable/equatable.dart';

/// Identidade pública mínima de um usuário (RN-06: protege dados sensíveis).
class UserSummary extends Equatable {
  const UserSummary({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String handle;
  final String avatarUrl;

  @override
  List<Object?> get props => <Object?>[id, name, handle, avatarUrl];
}
