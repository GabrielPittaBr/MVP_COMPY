import '../../../../shared/models/event.dart';
import '../entities/sport_category.dart';

/// Contrato de dados da Home.
///
/// Stream para que ligações com Firestore sejam plug-and-play
/// (RNF02: tempo real); listas de categorias são síncronas.
abstract interface class HomeRepository {
  List<SportCategory> getCategories();
  Stream<List<Event>> watchNearbyEvents();
}
