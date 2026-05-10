import '../entities/sport_category.dart';
import '../repositories/home_repository.dart';

class GetCategories {
  const GetCategories(this._repository);
  final HomeRepository _repository;

  List<SportCategory> call() => _repository.getCategories();
}
