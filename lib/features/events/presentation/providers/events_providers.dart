import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/event.dart';
import '../../data/datasources/events_remote_datasource.dart';
import '../../data/repositories/events_repository_impl.dart';
import '../../domain/repositories/events_repository.dart';
import '../../domain/usecases/create_event.dart';
import '../../domain/usecases/get_event_detail.dart';
import '../../domain/usecases/join_event.dart';

final eventsRemoteDataSourceProvider = Provider<EventsRemoteDataSource>(
  (ref) => EventsRemoteDataSource(FirebaseFirestore.instance),
);

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepositoryImpl(ref.watch(eventsRemoteDataSourceProvider)),
);

final getEventDetailProvider = Provider<GetEventDetail>(
  (ref) => GetEventDetail(ref.watch(eventsRepositoryProvider)),
);

final joinEventProvider = Provider<JoinEvent>(
  (ref) => JoinEvent(ref.watch(eventsRepositoryProvider)),
);

final createEventProvider = Provider<CreateEvent>(
  (ref) => CreateEvent(ref.watch(eventsRepositoryProvider)),
);

/// Stream da lista completa — observada pela tela "5 Eventos".
final allEventsProvider = StreamProvider<List<Event>>(
  (ref) => ref.watch(eventsRepositoryProvider).watchAll(),
);

/// Detalhe de um evento por id. `family` permite cachear por id.
final eventDetailProvider =
    FutureProvider.family<Event?, String>((ref, id) async {
  // Re-emite quando a lista global mudar (após join/create).
  ref.watch(allEventsProvider);
  return ref.watch(getEventDetailProvider).call(id);
});
