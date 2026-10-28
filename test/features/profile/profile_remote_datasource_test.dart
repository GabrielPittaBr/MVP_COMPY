import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/services/avatar_storage.dart';
import 'package:mvp_compy/features/profile/data/datasources/profile_remote_datasource.dart';

class _User implements User {
  @override
  String get uid => 'owner';
  @override
  String? displayName = 'João';
  Object? error;
  int updates = 0;
  @override
  Future<void> updateDisplayName(String? name) async {
    updates++;
    if (error != null) throw error!;
    displayName = name;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User? currentUser = _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Dublês locais do SDK, apenas para injetar falhas e inspecionar o merge.
// O contrato de permissões é exercitado separadamente nos emuladores.
// ignore: subtype_of_sealed_class, must_be_immutable
class _Document implements DocumentReference<Map<String, dynamic>> {
  Map<String, dynamic>? payload;
  SetOptions? options;
  Object? error;
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (error != null) throw error!;
    payload = data;
    this.options = options;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Collection implements CollectionReference<Map<String, dynamic>> {
  final document = _Document();
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'owner');
    return document;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firestore implements FirebaseFirestore {
  final users = _Collection();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'users');
    return users;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Avatars implements AvatarStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Auth auth;
  late _Firestore firestore;
  late ProfileRemoteDataSource remote;
  setUp(() {
    auth = _Auth();
    firestore = _Firestore();
    remote = ProfileRemoteDataSource(firestore, _Avatars(), auth: auth);
  });

  test(
      'payload usa UID correto, normaliza nameLower e faz merge somente dos detalhes',
      () async {
    await remote.updatePublicDetails('owner', 'João Silva', '');
    expect(firestore.users.document.payload,
        {'name': 'João Silva', 'nameLower': 'joao silva', 'bio': ''});
    expect(firestore.users.document.options!.merge, isTrue);
    expect((auth.currentUser! as _User).updates, 0);
  });

  test('sem sessao ou UID divergente nao escreve nem sincroniza', () async {
    for (final uid in ['', 'other', 'owner']) {
      if (uid == 'owner') auth.currentUser = null;
      await expectLater(
          remote.updatePublicDetails(uid, 'João', 'Bio'), throwsStateError);
      await expectLater(
          remote.updateAuthDisplayName(uid, 'João'), throwsStateError);
    }
    expect(firestore.users.document.payload, isNull);
  });

  test('Auth igual nao faz chamada; nome diferente sincroniza uma vez',
      () async {
    final user = auth.currentUser! as _User;
    await remote.updateAuthDisplayName('owner', 'João');
    expect(user.updates, 0);
    await remote.updateAuthDisplayName('owner', 'João Silva');
    await remote.updateAuthDisplayName('owner', 'João Silva');
    expect(user.updates, 1);
    expect(user.displayName, 'João Silva');
  });

  test('preserva FirebaseException e codigo do Firestore para diagnostico',
      () async {
    final error =
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    firestore.users.document.error = error;
    await expectLater(remote.updatePublicDetails('owner', 'João', 'Bio'),
        throwsA(same(error)));
    expect((auth.currentUser! as _User).updates, 0);
  });

  test('preserva erro de Auth e permite repetir sem perder perfil escrito',
      () async {
    final user = auth.currentUser! as _User;
    final error = FirebaseAuthException(code: 'network-request-failed');
    user.error = error;
    await remote.updatePublicDetails('owner', 'João Silva', 'Bio');
    await expectLater(remote.updateAuthDisplayName('owner', 'João Silva'),
        throwsA(same(error)));
    expect(firestore.users.document.payload!['bio'], 'Bio');
    user.error = null;
    await remote.updateAuthDisplayName('owner', 'João Silva');
    expect(user.displayName, 'João Silva');
  });
}
