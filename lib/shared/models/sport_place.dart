import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_assets.dart';
import 'sport.dart';

/// Local esportivo curado pela equipe (RF04 + RN-04: somente locais
/// validados aparecem no app).
///
/// **Fonte de verdade única de locais.** O mapa (pins) e o seletor de
/// "Criar evento" leem desta mesma lista: cadastrar um local aqui o faz
/// aparecer nos dois lugares, com o mesmo `id` — a navegação do pin para
/// a criação de evento depende desse id estável.
///
/// O catálogo vive em código de propósito: são poucos locais, curados
/// pela equipe e que mudam raramente. Não existe coleção `places` no
/// Firestore (ver `firestore.rules`).
class SportPlace extends Equatable {
  const SportPlace({
    required this.id,
    required this.name,
    required this.city,
    required this.coordinates,
    required this.allowedSports,
    required this.imageUrl,
    required this.description,
    this.address = '',
    this.rating = 0,
    this.ratingsCount = 0,
  });

  final String id;
  final String name;
  final String city;

  /// Endereço completo. Fica vazio enquanto não for conferido — a UI
  /// esconde a linha em vez de mostrar endereço inventado.
  final String address;
  final LatLng coordinates;

  /// Esportes praticáveis no local — o usuário só cria evento aqui com um
  /// destes (RN: impedir esportes incompatíveis com a estrutura do local).
  ///
  /// O primeiro é a modalidade principal: define ícone e cor do pin.
  /// Todo local tem ao menos um.
  final List<Sport> allowedSports;
  final String imageUrl;

  /// Nota do local. **Não é dado real**: seria um número escrito à mão no
  /// catálogo, então o padrão é zero e a UI omite a nota enquanto
  /// [hasRatings] for falso. Vira média calculada quando a avaliação de
  /// locais existir (tarefa 14).
  final double rating;
  final int ratingsCount;
  final String description;

  /// Modalidade que representa o local no mapa.
  Sport get primarySport => allowedSports.first;

  /// Local ainda sem nenhuma avaliação — a UI omite a nota em vez de
  /// mostrar 0,0 estrelas.
  bool get hasRatings => ratingsCount > 0;

  // ── Catálogo curado ─────────────────────────────────────────────

  /// Parque do Trabalhador — o local mais usado para esportes em Taquara.
  /// Base para os demais locais que serão cadastrados conforme validados.
  static const SportPlace parqueDoTrabalhador = SportPlace(
    id: 'parque_do_trabalhador',
    name: 'Parque do Trabalhador',
    city: 'Taquara',
    coordinates: LatLng(-29.656276729317323, -50.787726691670045),
    allowedSports: <Sport>[
      Sport.futebol,
      Sport.basquete,
      Sport.futsal,
      Sport.volei,
      Sport.corrida,
      Sport.ciclismo,
      Sport.caminhada,
    ],
    imageUrl: AppAssets.soccerBanner,
    description: 'Parque público de Taquara, com campo de futebol, quadras e '
        'pista usada para corrida, ciclismo e caminhada.',
  );

  /// Locais disponíveis no app. Acrescentar aqui — e só aqui.
  static const List<SportPlace> all = <SportPlace>[parqueDoTrabalhador];

  /// Busca pelo [id] estável do catálogo. É como o local atravessa a
  /// navegação (pin do mapa → formulário de criação): viaja o id, não o
  /// objeto. Devolve `null` para id desconhecido — ex.: link antigo de um
  /// local que saiu do catálogo.
  static SportPlace? byId(String id) {
    for (final place in all) {
      if (place.id == id) return place;
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        city,
        address,
        coordinates,
        allowedSports,
        imageUrl,
        rating,
        ratingsCount,
        description,
      ];
}
