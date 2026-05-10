/// Strings da interface centralizadas.
///
/// Mantemos PT-BR como padrão. A organização por feature aqui prepara o
/// terreno para internacionalização (RNF11) sem reestruturação lógica:
/// basta substituir o backing por arb/intl no futuro.
abstract final class AppStrings {
  // App
  static const String appName = 'COMPY';

  // Bottom nav
  static const String navHome = 'Início';
  static const String navEvents = 'Eventos';
  static const String navCreate = 'Criar';
  static const String navChat = 'Chat';
  static const String navProfile = 'Perfil';

  // Home
  static const String homeGreetingPrefix = 'Oi,';
  static const String homeSearchHint = 'Encontre esportes';
  static const String homeCategories = 'Categorias';
  static const String homeExplore = 'Explore locais';
  static const String homeNearbyEvents = 'Eventos Próximos';
  static const String homeFilterByDate = 'Filtrar por data';

  // Maps
  static const String mapsSearchHint = 'Encontre esportes';

  // Events
  static const String eventsTitle = 'Eventos';
  static const String eventCreateTitle = 'Criar evento';
  static const String eventSelectSport = 'Selecionar esporte';
  static const String eventDate = 'Data';
  static const String eventTime = 'Horário';
  static const String eventSkillLevel = 'Nível de habilidade';
  static const String eventParticipants = 'Participantes';
  static const String eventVacancies = 'Vagas restantes';
  static const String eventLocation = 'Local';
  static const String eventCreate = 'Criar evento';
  static const String eventJoin = 'Participar';
  static const String eventFull = 'Evento sem vagas';
  static const String eventCreatedBy = 'Criado por:';
  static const String eventSeeMore = 'Ver mais';
  static const String eventVacanciesLabel = 'vagas restantes';

  // Profile
  static const String profileTitle = 'Perfil';
  static const String profileEdit = 'Editar perfil';
  static const String profileFavoriteSports = 'Esportes favoritos';
  static const String profileBadges = 'Insígnias';
  static const String profileFriends = 'Amigos';
  static const String profileRatings = 'Avaliações';
  static const String profileGallery = 'Galeria';
  static const String profileSeeMore = 'Ver mais';

  // Chat
  static const String chatTitle = 'Chat';
  static const String chatFindMore = 'Encontre mais companheiros...';
  static const String chatHint = 'Digite uma mensagem...';
  static const String chatToday = 'Hoje';
}
