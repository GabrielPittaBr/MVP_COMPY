import 'package:equatable/equatable.dart';

import '../../../../shared/models/sport.dart';

/// Categoria de esporte exibida no carrossel "Categorias" da Home.
class SportCategory extends Equatable {
  const SportCategory({
    required this.sport,
    required this.imageUrl,
  });

  final Sport sport;
  final String imageUrl;

  @override
  List<Object?> get props => <Object?>[sport, imageUrl];
}
