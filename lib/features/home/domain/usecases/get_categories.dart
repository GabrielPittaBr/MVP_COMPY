import '../../../../shared/models/sport.dart';
import '../entities/sport_category.dart';
import '../repositories/home_repository.dart';

class GetCategories {
  const GetCategories(this._repository);
  final HomeRepository _repository;

  List<SportCategory> call({List<Sport> favoriteSports = const <Sport>[]}) =>
      _repository.getCategories(favoriteSports: favoriteSports);
}
