import 'package:equatable/equatable.dart';

/// Identidade pública mínima de um usuário (RN-06: protege dados sensíveis).
///
/// O que esta classe omite, `users/{uid}` também omite: o e-mail vive em
/// `users/{uid}/private/contact`, fora do alcance da regra que deixa qualquer
/// autenticado ler o perfil.
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

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'handle': handle,
        'avatarUrl': avatarUrl,
      };

  factory UserSummary.fromMap(dynamic data) {
    if (data is! Map) {
      return const UserSummary(
        id: 'unknown',
        name: 'Desconhecido',
        handle: '@unknown',
        avatarUrl: '',
      );
    }
    return UserSummary(
      id: (data['id'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      handle: (data['handle'] as String?) ?? '',
      avatarUrl: (data['avatarUrl'] as String?) ?? '',
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, handle, avatarUrl];
}
