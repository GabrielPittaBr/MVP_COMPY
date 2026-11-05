import 'package:cloud_firestore/cloud_firestore.dart';

/// Datasource Firestore da Home.
///
/// Usa a **mesma consulta da aba Eventos** (`orderBy('dateTime')`): uma
/// leitura pontual, sem campo extra no documento e sem índice composto. O recorte
/// por distância acontece no repositório, sobre o lote recebido.
///
/// A versão anterior filtrava no servidor por geohash — nove `snapshots()`
/// em paralelo (célula central + vizinhas) mesclados no cliente. Além de
/// frágil (basta uma das nove falhar para a Home inteira ir a erro), ela
/// dependia do campo `geohash`, que só existe em documentos criados depois
/// que `Event.toMap()` passou a gravá-lo: o `orderBy('geohash')` descarta
/// silenciosamente todos os eventos antigos. Para o volume de um município,
/// filtrar no cliente é suficiente.
class HomeRemoteDataSource {
  HomeRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  /// Teto de documentos trazidos por vez. A Home mostra só os próximos, mas
  /// o corte por distância é no cliente — o lote precisa ser maior que a
  /// lista final.
  static const int defaultLimit = 50;

  /// Eventos mais próximos em data, ordenados por `dateTime`.
  ///
  /// `get`, e não listener: com 50 eventos ao vivo, cada inscrição em
  /// qualquer um deles gerava uma leitura para cada usuário com a Home
  /// aberta. As vagas na Home podem ficar um pouco atrasadas; o detalhe
  /// segue ao vivo e a inscrição valida as vagas na transação.
  ///
  /// [notBefore] corta os eventos que já não podem estar abertos (tarefa
  /// 14). Sem ele, o lote de [limit] documentos se enchia de eventos
  /// passados e os próximos ficavam de fora.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchEvents({
    int limit = defaultLimit,
    DateTime? notBefore,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('events');
    if (notBefore != null) {
      query = query.where('dateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(notBefore));
    }
    final snapshot = await query.orderBy('dateTime').limit(limit).get();
    return snapshot.docs;
  }
}
