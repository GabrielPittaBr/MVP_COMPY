import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_links.dart';

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
    this.photoUrl,
    this.legalVersion,
    this.birthDate,
    this.adultAt,
    this.ageSignalUpper,
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

  /// Foto do provedor (Google), quando houver. Só serve de sugestão na
  /// criação da conta: a foto que o app mostra é `users/{uid}.avatarUrl`.
  final String? photoUrl;

  /// Versão dos Termos aceita (`users/{uid}/private/consent.termsVersion`),
  /// ou `null` para contas anteriores ao aceite (chore/lgpd).
  final String? legalVersion;

  /// Data de nascimento declarada no aceite.
  final DateTime? birthDate;

  /// O 18º aniversário. Antes dele, valem as proteções de adolescente.
  final DateTime? adultAt;

  /// Teto da faixa etária que a Google Play informou, quando informou.
  final int? ageSignalUpper;

  /// Aceitou a versão atual dos Termos, com a data de nascimento registrada.
  /// `false` → redirecionar para /consentimento antes de entrar no app.
  bool get hasCurrentConsent =>
      legalVersion == AppLinks.legalVersion && birthDate != null;

  /// Tem 16 ou 17 anos, pela data declarada ou pela faixa da Play.
  bool isMinorAt(DateTime now) =>
      (adultAt != null && adultAt!.isAfter(now)) ||
      (ageSignalUpper != null && ageSignalUpper! < 18);

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? hasUsername,
    bool? hasFavoriteSports,
    String? photoUrl,
    String? legalVersion,
    DateTime? birthDate,
    DateTime? adultAt,
    int? ageSignalUpper,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      hasUsername: hasUsername ?? this.hasUsername,
      hasFavoriteSports: hasFavoriteSports ?? this.hasFavoriteSports,
      photoUrl: photoUrl ?? this.photoUrl,
      legalVersion: legalVersion ?? this.legalVersion,
      birthDate: birthDate ?? this.birthDate,
      adultAt: adultAt ?? this.adultAt,
      ageSignalUpper: ageSignalUpper ?? this.ageSignalUpper,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        uid,
        email,
        displayName,
        hasUsername,
        hasFavoriteSports,
        photoUrl,
        legalVersion,
        birthDate,
        adultAt,
        ageSignalUpper,
      ];
}
