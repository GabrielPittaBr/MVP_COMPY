import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Fotos de perfil no Cloud Storage, em `users/{uid}/avatar_<millis>.jpg`.
///
/// Mora em `core` porque dois features gravam aqui: auth (foto escolhida no
/// cadastro, limpeza na exclusão de conta) e profile (troca da foto).
class AvatarStorage {
  AvatarStorage(this._storage);

  final FirebaseStorage _storage;

  /// Envia o JPEG já preparado por `AvatarImage.toJpeg` e devolve a URL de
  /// download, que é o que vai para `users/{uid}.avatarUrl`.
  ///
  /// Nome novo a cada envio: a URL muda, então o cache do
  /// `CachedNetworkImage` nunca mostra a foto anterior.
  ///
  /// ponytail: a foto anterior fica no bucket porque conversas ainda exibem
  /// snapshots de avatar. Os eventos preservam a cópia histórica, mas seus
  /// detalhes já consultam o perfil atual para apresentação.
  Future<String> upload(String uid, Uint8List jpeg) async {
    final Reference ref = _storage
        .ref('users/$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Apaga todas as fotos do usuário. Usado na exclusão de conta.
  Future<void> deleteAll(String uid) async {
    final ListResult result = await _storage.ref('users/$uid').listAll();
    await Future.wait(result.items.map((Reference item) => item.delete()));
  }
}
