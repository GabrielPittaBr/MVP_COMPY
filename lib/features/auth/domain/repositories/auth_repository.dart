import 'dart:typed_data';

import '../entities/auth_user.dart';
import '../entities/legal_consent.dart';

/// Interface do repositório de autenticação.
///
/// Define o contrato que a camada de apresentação conhece — sem depender do
/// Firebase diretamente (Dependency Inversion Principle).
abstract interface class AuthRepository {
  /// Stream do estado de autenticação (emite null quando deslogado).
  Stream<AuthUser?> authState();

  /// Login com e-mail e senha.
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// Cadastro manual: cria conta no FirebaseAuth + perfil no Firestore.
  ///
  /// [photo] é a foto de perfil já recortada, em JPEG; `null` deixa a
  /// inicial do nome. Se o envio dela falhar, o cadastro segue sem foto.
  ///
  /// [consent] é o aceite dos Termos com a data de nascimento, gravado no
  /// mesmo batch do perfil (chore/lgpd).
  Future<AuthUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
    required LegalConsentInput consent,
    Uint8List? photo,
  });

  /// Login / cadastro via Google.
  ///
  /// Retorna um [AuthUser] onde [AuthUser.hasUsername] será `false` se for
  /// a primeira vez do usuário (fluxo intermediário de escolha de username).
  Future<AuthUser> signInWithGoogle();

  /// Verifica se o [username] ainda está disponível no Firestore.
  ///
  /// [forUid] é o dono esperado: um username já registrado para esse uid
  /// continua disponível **para ele**.
  Future<bool> isUsernameAvailable(String username, {String? forUid});

  /// Grava o username escolhido (fluxo pós-Google para novos usuários).
  /// Cria/atualiza `users/{uid}` e `usernames/{username}` no Firestore.
  ///
  /// A foto do perfil é [photo] (JPEG recortado) quando houver, senão
  /// [photoUrl] (a do Google), senão a inicial do nome.
  Future<void> setUsername({
    required String uid,
    required String username,
    required String name,
    required String email,
    required LegalConsentInput consent,
    Uint8List? photo,
    String? photoUrl,
  });

  /// Registra o aceite da versão atual dos Termos para quem já tem conta.
  /// [consent] só é obrigatório quando ainda não há data de nascimento.
  Future<AuthUser> acceptLegalTerms({LegalConsentInput? consent});

  /// Apaga a conta Google recém-criada de quem tem menos de 16 anos, antes de
  /// gravar o perfil, e sai.
  Future<void> abortUnderageSignup();

  /// Faz logout do Firebase Auth.
  Future<void> signOut();

  /// `true` quando a exclusão de conta vai precisar da senha do usuário.
  ///
  /// Quem entrou com Google reautentica pelo seletor da própria Google e não
  /// digita senha nenhuma.
  bool signedInWithPassword();

  /// Apaga a conta: as fotos de perfil no Storage, `users/{uid}`, o contato
  /// privado, a reserva do username e o registro no Firebase Auth.
  ///
  /// Reautentica antes de apagar qualquer coisa — o Firebase exige login
  /// recente. [password] é obrigatória quando [signedInWithPassword] devolve
  /// `true` e ignorada nos outros casos.
  Future<void> deleteAccount({String? password});
}
