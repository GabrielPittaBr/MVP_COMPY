/// Modalidades aceitas pelo COMPY: nome gravado no Firestore → rótulo PT-BR.
///
/// É a **única** cópia da lista no painel: o filtro e o formulário de locais,
/// a lista de eventos e a lista de usuários leem daqui. Fora do painel, a
/// mesma lista vive no enum `Sport` do app, em `validSports()` do
/// `firestore.rules` e em `supportedSports` do Admin SDK. Esporte novo entra
/// nos quatro, senão o local com ele não salva ou aparece com o nome cru.
///
/// A ordem é a do enum do app, e é a dos chips do formulário e do filtro.
const Map<String, String> adminSportLabels = <String, String>{
  'futebol': 'Futebol',
  'futsal': 'Futsal',
  'basquete': 'Basquete',
  'volei': 'Vôlei',
  'handebol': 'Handebol',
  'tenis': 'Tênis',
  'tenisDeMesa': 'Tênis de mesa',
  'padel': 'Padel',
  'futebolDeAreia': 'Futebol de areia',
  'voleiDePraia': 'Vôlei de praia',
  'futevolei': 'Futevôlei',
  'beachTennis': 'Beach tennis',
  'corrida': 'Corrida',
  'ciclismo': 'Ciclismo',
  'caminhada': 'Caminhada',
  'skate': 'Skate',
};

/// Rótulo PT-BR de um nome gravado. Um nome que o painel não conhece aparece
/// cru, para o administrador perceber que há algo fora do contrato.
String adminSportLabel(String sport) => adminSportLabels[sport] ?? sport;
