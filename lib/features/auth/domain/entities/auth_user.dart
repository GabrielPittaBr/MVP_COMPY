import 'package:equatable/equatable.dart';

/// Entidade que representa o usuário autenticado no contexto do app.
///
/// Contém apenas os dados que o domínio precisa — não expõe objetos do
/// Firebase diretamente (facilita testes e troca de provedor).
class AuthUser extends Equatable {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.hasUsername,
    required this.hasFavoriteSports,
  });

  /// UID do Firebase Auth.
  final String uid;

  /// E-mail do usuário (pode ser vazio para contas anônimas).
  final String email;

  /// Nome exibido — vindo do Google ou preenchido no cadastro.
  final String displayName;

  /// Indica se o usuário já escolheu um username no Firestore.
  /// `false` → redirecionar para /username antes de entrar no app.
  final bool hasUsername;

  /// Indica se o usuário já **passou** pela escolha de esportes favoritos.
  /// `false` → redirecionar para /onboarding/esportes antes de entrar no app.
  ///
  /// Passar pela tela e não escolher nada conta como ter passado: quem pula
  /// grava lista vazia e o campo existe. Se este sinal exigisse ao menos um
  /// esporte, o guard devolveria quem pulou para a tela, indefinidamente.
  final bool hasFavoriteSports;

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? hasUsername,
    bool? hasFavoriteSports,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      hasUsername: hasUsername ?? this.hasUsername,
      hasFavoriteSports: hasFavoriteSports ?? this.hasFavoriteSports,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[uid, email, displayName, hasUsername, hasFavoriteSports];
}
