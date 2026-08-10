/// Strings da interface centralizadas.
///
/// Mantemos PT-BR como padrão. A organização por feature aqui prepara o
/// terreno para internacionalização (RNF11) sem reestruturação lógica:
/// basta substituir o backing por arb/intl no futuro.
abstract final class AppStrings {
  // App
  static const String appName = 'COMPY';

  // Comum
  static const String commonCancel = 'Cancelar';
  static const String commonConfirm = 'Confirmar';

  // Bottom nav
  static const String navHome = 'Início';
  static const String navEvents = 'Eventos';
  static const String navCreate = 'Criar';
  static const String navChat = 'Chat';
  static const String navProfile = 'Perfil';

  // Home
  static const String homeGreetingPrefix = 'Oi,';
  static const String homeSearchHint = 'Encontre esportes';

  // Busca
  static const String searchHint = 'Buscar evento ou esporte';
  static const String searchPrompt =
      'Digite ao menos 2 letras para buscar por\nnome do evento ou modalidade esportiva.';
  static const String searchNoResults = 'Nenhum evento encontrado.';
  static const String homeCategories = 'Categorias';
  static const String homeExplore = 'Explore locais';
  static const String homeNearbyEvents = 'Eventos Próximos';
  static const String homeFilterByDate = 'Filtrar por data';

  // Maps
  static const String mapsSearchHint = 'Encontre esportes';
  static const String mapsPlaceInfo = 'Informações';

  // Events
  static const String eventsTitle = 'Eventos';
  static const String eventCreateTitle = 'Criar evento';
  static const String eventTitle = 'Título';
  static const String eventTitleHint =
      'Título (ex.: Pelada de quinta, Vôlei descontraído)';
  static const String eventSelectSport = 'Selecionar esporte';
  static const String eventSelectLocation = 'Selecionar local';
  static const String eventSelectLocationFirst =
      'Selecione o local do evento primeiro.';
  static const String eventDate = 'Data';
  static const String eventTime = 'Horário';
  static const String eventDuration = 'Duração';
  static const String eventDurationOther = 'Outro';
  static const String eventDurationCustomTitle = 'Duração personalizada';
  static const String eventDurationCustomHint = 'Duração em minutos';
  static const String eventDurationCustomInvalid =
      'Informe uma duração entre 15 e 720 minutos.';
  static const String eventSkillLevel = 'Nível de habilidade';
  static const String eventParticipants = 'Participantes';
  static const String eventParticipantsNumber = 'Número de participantes';
  static const String eventDescription = 'Descrição';
  static const String eventDescriptionHint =
      'Conte como vai ser o jogo: leve bola? tem colete? '
      'é competitivo ou de boa?';
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
  static const String chatYesterday = 'Ontem';
  static const String chatConversationUnavailable =
      'Esta conversa não está disponível.';
  static const String chatFallbackTitle = 'Conversa';
  static const String chatNewConversation = 'Nova conversa';
  static const String chatSearchHandleHint = 'Buscar por @handle';
  static const String chatSearchPrompt =
      'Digite ao menos 2 letras do handle para buscar.';
  static const String chatSearchEmpty = 'Ninguém encontrado com esse handle.';
  static const String chatSearchError = 'Não foi possível buscar agora.';
  static const String chatOpenConversationError =
      'Não foi possível abrir a conversa.';

  // Auth — login / cadastro / username
  static const String authTagline = 'Ache seu próximo jogo em Taquara';
  static const String authLoginWithEmail = 'Entrar com email';
  static const String authLoginWithGoogle = 'Entrar com Google';
  static const String authCreateAccount = 'Criar Conta';
  static const String authPrivacyPrefix = 'Ao continuar, você concorda com nossa';
  static const String authPrivacyPolicy = 'Política de Privacidade';
  static const String authName = 'Nome completo';
  static const String authUsername = 'Username (ex.: @joao)';
  static const String authEmail = 'E-mail';
  static const String authPassword = 'Senha (mín. 6 caracteres)';
  static const String authLoginTitle = 'Bem-vindo ao COMPY';
  static const String authSignupTitle = 'Criar conta';
  static const String authSignupButton = 'Cadastrar';
  static const String authAlreadyHaveAccount = 'Já tenho uma conta';
  static const String authChooseUsername = 'Escolha seu username';
  static const String authChooseUsernameHint =
      'Defina um username exclusivo para sua conta.';
  static const String authUsernameField = 'Username';
  static const String authConfirmUsername = 'Confirmar';
  static const String authBack = 'Voltar';
  static const String authLoading = 'Aguarde...';
  static const String authErrorUsernameTaken = 'Este username já está em uso.';
  static const String authErrorUsernameEmpty = 'O username não pode ser vazio.';
  static const String authErrorUsernameTooShort =
      'O username precisa ter ao menos 3 caracteres.';
  static const String authErrorUsernameTooLong =
      'O username pode ter no máximo 20 caracteres.';
  static const String authErrorUsernameInvalidChars =
      'Use apenas letras, números, ponto e _ — sem começar ou terminar com ponto.';
  static const String authErrorEmailInvalid = 'Informe um e-mail válido.';
  static const String authErrorPasswordShort = 'A senha precisa ter ao menos 6 caracteres.';
  static const String authErrorNameEmpty = 'Informe seu nome.';
  static const String authErrorGeneric = 'Ocorreu um erro. Tente novamente.';
  static const String authErrorInvalidCredential = 'E-mail ou senha incorretos.';
  static const String authErrorEmailAlreadyInUse = 'Este e-mail já está cadastrado.';
}