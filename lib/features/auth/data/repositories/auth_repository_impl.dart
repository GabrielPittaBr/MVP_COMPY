import 'dart:typed_data';

import '../../domain/entities/auth_user.dart';
import '../../domain/entities/legal_consent.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implementação concreta de [AuthRepository].
///
/// Delega toda a lógica ao [AuthRemoteDataSource] e converte exceções do
/// datasource em exceções de domínio quando necessário.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required AuthRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final AuthRemoteDataSource _dataSource;

  @override
  Stream<AuthUser?> authState() => _dataSource.authState();

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _dataSource.signInWithEmail(email: email, password: password);

  @override
  Future<AuthUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
    required LegalConsentInput consent,
    Uint8List? photo,
  }) =>
      _dataSource.signUpWithEmail(
        name: name,
        username: username,
        email: email,
        password: password,
        consent: consent,
        photo: photo,
      );

  @override
  Future<AuthUser> signInWithGoogle() => _dataSource.signInWithGoogle();

  @override
  Future<bool> isUsernameAvailable(String username, {String? forUid}) =>
      _dataSource.isUsernameAvailable(username, forUid: forUid);

  @override
  Future<void> setUsername({
    required String uid,
    required String username,
    required String name,
    required String email,
    required LegalConsentInput consent,
    Uint8List? photo,
    String? photoUrl,
  }) =>
      _dataSource.setUsername(
        uid: uid,
        username: username,
        name: name,
        email: email,
        consent: consent,
        photo: photo,
        photoUrl: photoUrl,
      );

  @override
  Future<AuthUser> acceptLegalTerms({LegalConsentInput? consent}) =>
      _dataSource.acceptLegalTerms(consent: consent);

  @override
  Future<void> abortUnderageSignup() => _dataSource.abortUnderageSignup();

  @override
  Future<void> signOut() => _dataSource.signOut();

  @override
  bool signedInWithPassword() => _dataSource.signedInWithPassword();

  @override
  Future<void> deleteAccount({String? password}) =>
      _dataSource.deleteAccount(password: password);
}
