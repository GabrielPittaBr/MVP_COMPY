import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/utils/geohash.dart';

/// Datasource Firestore da Home.
///
/// Busca eventos por raio de distância usando geohash (estratégia
/// GeoFlutterFire): calcula as células que cobrem o raio, faz uma range
/// query por célula (`orderBy('geohash').startAt/endAt`) e mescla os
/// resultados. O filtro fino por distância exata fica no repositório.
class HomeRemoteDataSource {
  HomeRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  /// Stream dos eventos dentro das células geohash que cobrem o círculo
  /// de raio [radiusKm] centrado em [center]. Documentos sem o campo
  /// `geohash` são ignorados pelo Firestore (não entram no orderBy).
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchNearbyEvents({
    required LatLng center,
    required double radiusKm,
  }) {
    final cells = Geohash.coveringCells(
      center.latitude,
      center.longitude,
      radiusKm,
    );

    final streams = <Stream<QuerySnapshot<Map<String, dynamic>>>>[
      for (final cell in cells)
        _firestore
            .collection('events')
            .orderBy('geohash')
            .startAt(<String>[cell])
            .endAt(<String>['$cell~'])
            .snapshots(),
    ];

    return _combineLatest(streams).map((snapshots) {
      // Mescla as células e deduplica por id (um doc só pertence a uma
      // célula, mas o merge protege contra células sobrepostas).
      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          byId[doc.id] = doc;
        }
      }
      return byId.values.toList();
    });
  }

  /// Combina N streams emitindo a lista dos últimos valores sempre que
  /// qualquer uma emite (após todas terem emitido ao menos uma vez).
  static Stream<List<T>> _combineLatest<T>(List<Stream<T>> streams) {
    final controller = StreamController<List<T>>();
    final latest = List<T?>.filled(streams.length, null);
    final hasValue = List<bool>.filled(streams.length, false);
    final subscriptions = <StreamSubscription<T>>[];

    controller.onListen = () {
      for (var i = 0; i < streams.length; i++) {
        subscriptions.add(
          streams[i].listen(
            (value) {
              latest[i] = value;
              hasValue[i] = true;
              if (!hasValue.contains(false)) {
                controller.add(List<T>.unmodifiable(latest.cast<T>()));
              }
            },
            onError: controller.addError,
          ),
        );
      }
    };
    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    };
    return controller.stream;
  }
}
