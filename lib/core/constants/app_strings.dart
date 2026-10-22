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
  static const String homeSeeMoreCategories = 'Ver mais';
  static const String homeExplore = 'Explore locais';
  static const String homeNearbyEvents = 'Eventos Próximos';
  static const String homeFilterByDate = 'Filtrar por data';
  static const String homeNearbyEmpty =
      'Nenhum evento perto de você por enquanto.';
  static const String homeNearbyError =
      'Não foi possível carregar os eventos próximos.';

  // Maps
  static const String mapsSearchHint = 'Encontre esportes';
  static const String mapsPlaceInfo = 'Informações';
  static const String mapsOfflineNoCache =
      'Sem conexão e nenhum local salvo neste dispositivo.';

  // Events
  static const String eventsTitle = 'Eventos';
  static const String eventsEmpty = 'Nenhum evento disponível.';
  static const String eventsEmptyFiltered =
      'Nenhum evento com esses filtros por enquanto.';
  static const String eventsClearFilter = 'Limpar filtro';
  static const String eventsCreateCta = 'Criar um evento';

  /// Estado vazio da lista quando há filtro de modalidade ativo.
  static String eventsEmptyForSport(String sportLabel) =>
      'Nenhum evento de $sportLabel por enquanto.';

  // Seções da aba Eventos — cada uma some junto do seu título quando não
  // tem nada para mostrar (D3).
  static const String eventsSectionMine = 'Criados por mim';
  static const String eventsSectionJoined = 'Participando';
  static const String eventsSectionAll = 'Todos os eventos';
  static const String eventsSectionError =
      'Não foi possível carregar esta seção.';

  // Filtros da aba Eventos
  static const String eventsFilters = 'Filtros';
  static const String eventsFilterTitle = 'Filtrar eventos';
  static const String eventsFilterSport = 'Modalidade';
  static const String eventsFilterSkillLevel = 'Nível de habilidade';
  static const String eventsFilterSkillLevelHint =
      'Eventos abertos a todos os níveis aparecem em qualquer escolha.';
  static const String eventsFilterDay = 'Data';
  static const String eventsFilterAnyDay = 'Qualquer data';
  static const String eventsFilterApply = 'Aplicar';
  static const String eventsFilterClearAll = 'Limpar tudo';
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
  static const String eventStartInPast =
      'Esse horário já passou. Escolha um início a partir de agora.';
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

  /// Versão curta para o CTA do card, que é estreito.
  static const String eventCardFull = 'Sem vagas';
  static const String eventCreatedBy = 'Criado por:';
  static const String eventSeeMore = 'Ver mais';
  static const String eventVacanciesLabel = 'vagas restantes';
  static String eventParticipantsCount(int count) => 'Participantes ($count)';
  static const String eventJoined = 'Você entrou no evento!';
  static const String eventNotFound = 'Evento não encontrado.';
  static const String eventJoinError = 'Erro ao entrar no evento';

  // Ciclo de vida do evento (tarefa 14)
  static const String eventStatusLive = 'Acontecendo agora';
  static const String eventStatusEnded = 'Encerrado';
  static const String eventStatusEndedAutomatically =
      'Encerrado automaticamente';
  static const String eventYouAreIn = 'Você está participando';
  static const String eventYouOrganize = 'Você organiza este evento';
  static const String eventAlreadyEnded = 'Este evento já terminou';

  // Evento ao vivo (tarefa 14)
  static const String eventLiveBadge = 'AO VIVO';
  static String eventLiveEndsAt(String time) => 'Termina às $time';
  static const String eventLiveOverdue = 'Horário previsto encerrado';
  static const String eventLiveOpen = 'Abrir evento';
  static const String eventLiveOpenFromDetail = 'Abrir evento ao vivo';
  static const String eventLiveTitle = 'Evento ao vivo';
  static String eventLiveSchedule(String start, String end) =>
      'Começou às $start · termina às $end';
  static String eventLiveRemaining(String duration) => 'Faltam $duration';
  static String eventLiveOverdueBy(String duration) =>
      'Passou $duration do previsto';
  static const String eventLiveOrganizer = 'Organizador';
  static const String eventLiveYou = 'Você';
  static String eventLiveMessage(String name) => 'Mandar mensagem para $name';
  static const String eventLiveTalkToOrganizer = 'Falar com o organizador';
  static const String eventLiveOverdueCreator =
      'O horário previsto acabou. Encerre o evento para liberar as avaliações.';
  static const String eventLiveOverdueParticipant =
      'O horário previsto acabou. O organizador ainda vai encerrar o evento.';
  static const String eventEnd = 'Encerrar evento';
  static const String eventEndConfirmTitle = 'Encerrar o evento agora?';
  static const String eventEndConfirmBody =
      'Os participantes vão receber o convite para avaliar. '
      'Não dá para desfazer.';
  static const String eventEndConfirm = 'Encerrar';
  static const String eventEndedByOrganizer = 'O organizador encerrou o evento.';
  static const String eventEndError =
      'Não foi possível encerrar o evento. Tente de novo.';
  static const String eventAlreadyEndedError = 'Este evento já foi encerrado.';
  static const String eventLiveRateNow = 'Avaliar agora';
  static const String eventRate = 'Avaliar evento';
  static const String eventRateAsCreator = 'Avaliar local e participantes';
  static const String eventAlreadyRated = 'Você já avaliou';
  static String eventParticipantsShort(int count) =>
      count == 1 ? '1 participante' : '$count participantes';

  // Central de notificações (tarefa 14)
  static const String notificationsTitle = 'Notificações';
  static const String notificationsMarkAllRead = 'Marcar todas como lidas';
  static const String notificationsNew = 'Novas';
  static const String notificationsEarlier = 'Anteriores';
  static const String notificationsEmptyTitle = 'Nada por aqui ainda';
  static const String notificationsEmptyBody =
      'Quando um evento de que você participou terminar, o convite para '
      'avaliar aparece aqui.';
  static String notificationsBellSemantics(int unread) => switch (unread) {
        0 => notificationsTitle,
        1 => '$notificationsTitle, 1 não lida',
        _ => '$notificationsTitle, $unread não lidas',
      };
  static String notificationEventEndedTitle(String eventTitle) =>
      '$eventTitle terminou';
  static const String notificationEventEndedBodyParticipant =
      'Como foi? Avalie o evento, o local e quem jogou com você.';
  static const String notificationEventEndedBodyCreator =
      'Como foi? Avalie o local e quem jogou com você.';
  static const String notificationAutoEndedTitle =
      'Seu evento foi encerrado automaticamente';
  static String notificationAutoEndedBody(String eventTitle) =>
      '$eventTitle passou 1h do horário previsto. '
      'Avalie o local e os participantes.';
  static const String notificationRated = 'Avaliado';
  static String autoEndDialogBody(String eventTitle) =>
      '$eventTitle passou 1h do horário previsto e encerramos por você. '
      'Que tal avaliar o local e quem jogou?';
  static const String autoEndDialogLater = 'Agora não';
  static const String autoEndDialogRate = 'Avaliar';
  static const String notificationUnread = 'Não lida';

  // Tempo relativo ("há 2 h") — central de notificações
  static const String timeNow = 'agora';
  static String timeMinutesAgo(int minutes) => 'há $minutes min';
  static String timeHoursAgo(int hours) => 'há $hours h';
  static const String timeYesterday = 'ontem';
  static String timeDaysAgo(int days) => 'há $days dias';

  // Avaliação do evento (tarefa 14)
  static const String ratingTitle = 'Avaliar evento';
  static String ratingStep(int index, int total) => 'Passo $index de $total';
  static const String ratingEventQuestion = 'Como foi o evento?';
  static const String ratingPlaceQuestion = 'E o local?';
  static const String ratingParticipantsQuestion = 'Quem jogou com você';
  static const String ratingOptional = 'Opcional';
  static const String ratingSkip = 'Pular';
  static const String ratingSkipAll = 'Pular todas';
  static const String ratingSkipped = 'Pulado';
  static const String ratingUndo = 'Desfazer';
  static const List<String> ratingStarLabels = <String>[
    'Péssimo',
    'Ruim',
    'Ok',
    'Bom',
    'Excelente',
  ];
  static String ratingStarsSemantics(int stars) => '$stars de 5 estrelas';
  static const String ratingCommentHint = 'Conte o que aconteceu (opcional)';
  static const String ratingCommentReasonHint = 'Por que essa nota?';
  static const String ratingCommentLocked = 'Escolha as estrelas para comentar';
  static const String ratingReasonRequired =
      'Para notas abaixo de 3, conte o motivo.';
  static const String ratingCommentPrivate =
      'Seu comentário não fica público: só a média aparece.';
  static const String ratingContinue = 'Continuar';
  static const String ratingSubmit = 'Enviar avaliação';
  static const String ratingSending = 'Enviando...';
  static const String ratingSent = 'Avaliação enviada!';
  static const String ratingThanks = 'Obrigado por ajudar a comunidade do COMPY.';
  static const String ratingBack = 'Voltar';
  static const String ratingClose = 'Fechar';
  static const String ratingExitTitle = 'Sair sem enviar?';
  static const String ratingExitBody = 'O que você preencheu vai se perder.';
  static const String ratingExitConfirm = 'Sair';
  static const String ratingNothingToRate = 'Não há o que avaliar neste evento.';
  static const String ratingErrorAlreadyRated = 'Você já avaliou este evento.';
  static const String ratingErrorNotEnded = 'Este evento ainda não terminou.';
  static const String ratingErrorNotParticipant =
      'Só quem participou pode avaliar.';
  static const String ratingErrorOffline =
      'Sem conexão. Tente de novo quando a internet voltar.';
  static const String ratingErrorGeneric = 'Não foi possível enviar a avaliação.';

  // Profile
  static const String profileTitle = 'Perfil';
  static const String profileEdit = 'Editar perfil';
  static const String profileEditFavoriteSports = 'Editar esportes favoritos';
  static const String profileFavoriteSports = 'Esportes favoritos';
  static const String profileBadges = 'Insígnias';
  static const String profileFriends = 'Amigos';
  static const String profileRatings = 'Avaliações';
  static const String profileGallery = 'Galeria';
  static const String profileSeeMore = 'Ver mais';

  // Profile — estado vazio das avaliações. Sem nota nenhuma a média é 0, e
  // "0,0" na tela é lido como nota baixa, não como ausência de nota.
  static const String profileNoRatings = 'Você não tem avaliações ainda';
  static const String profileNoRatingsHint =
      'Elas aparecem aqui depois que você participar de eventos e receber notas.';

  // Profile — edição do perfil e exclusão de conta
  static const String profileUsernameLocked =
      'Ainda não é possível alterar seu username. Estamos trabalhando nisso.';
  static const String profileAccountSection = 'Conta';
  static const String profileDeleteAccount = 'Excluir minha conta';
  static const String profileDeleteAccountHint =
      'Apaga seu perfil, libera seu @username e encerra seu acesso ao COMPY.';
  static const String profileDeleteAccountTitle = 'Excluir conta?';
  static const String profileDeleteAccountBody =
      'Esta ação não pode ser desfeita. Eventos que você criou e mensagens já '
      'enviadas continuam visíveis para os outros participantes.';
  static const String profileDeleteAccountPasswordHint = 'Confirme sua senha';
  static const String profileDeleteAccountPasswordEmpty =
      'Digite sua senha para confirmar a exclusão.';
  static const String profileDeleteAccountGoogleHint =
      'Vamos abrir o Google para você confirmar que é você mesmo.';
  static const String profileDeleteAccountConfirm = 'Excluir conta';

  // Chat
  static const String chatTitle = 'Chat';
  static const String chatFindMore = 'Encontre mais companheiros...';
  static const String chatHint = 'Digite uma mensagem...';
  static const String chatToday = 'Hoje';
  static const String chatYesterday = 'Ontem';
  static const String chatConversationUnavailable =
      'Esta conversa não está disponível.';
  static const String chatFallbackTitle = 'Conversa';
  static const String chatUnknownPeer = 'Desconhecido';
  static const String chatNewConversation = 'Nova conversa';
  static const String chatSearchHandleHint = 'Buscar por @handle';
  static const String chatSearchPrompt =
      'Digite ao menos 2 letras do handle para buscar.';
  static const String chatSearchEmpty = 'Ninguém encontrado com esse handle.';
  static const String chatSearchError = 'Não foi possível buscar agora.';
  static const String chatOpenConversationError =
      'Não foi possível abrir a conversa.';
  static const String chatForwardedPlace = 'Encaminhou um local...';
  static const String chatShareTo = 'Enviar para';
  static const String chatShareNoConversations =
      'Você ainda não tem conversas. Comece uma para compartilhar o local.';
  static const String chatShareError = 'Não foi possível compartilhar o local.';
  static const String chatShareNeedsConnection =
      'Reconecte-se à internet para compartilhar este local. O envio não foi feito.';
  static const String chatPlaceNoLongerActive =
      'Este local não está mais ativo e não pode ser compartilhado.';
  static const String mapsShare = 'Compartilhar';

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
  static const String authErrorProfileLookup =
      'Não foi possível carregar seu perfil. Verifique a conexão e tente novamente.';
  static const String authRetry = 'Tentar novamente';
  static const String authErrorInvalidCredential = 'E-mail ou senha incorretos.';
  static const String authErrorEmailAlreadyInUse = 'Este e-mail já está cadastrado.';
  static const String authErrorRequiresRecentLogin =
      'Por segurança, entre novamente para concluir a exclusão da conta.';

  // Onboarding — esportes favoritos
  static const String onboardingSportsTitle =
      'Muito bem! Agora vamos personalizar seu perfil:';
  static const String onboardingSportsHint =
      'Escolha os esportes que você mais curte. É por eles que o COMPY monta o que você vê primeiro.';
  static const String onboardingSportsContinue = 'Continuar';
  static const String onboardingSportsSkip = 'Pular por agora';
  static const String onboardingSportsSave = 'Salvar';
  static const String onboardingSportsEditTitle = 'Esportes favoritos';
  static const String onboardingSportsEditHint =
      'Marque ou desmarque à vontade — dá para mudar quando quiser.';
  static const String onboardingSportsSaveError =
      'Não foi possível salvar seus esportes. Tente novamente.';

  // Em construção — os botões já existem; as telas, ainda não.
  static const String settingsTitle = 'Configurações';
  static const String underConstructionTitle = 'Estamos trabalhando nisso';
  static const String underConstructionBody =
      'Esta parte do COMPY ainda está em construção. '
      'Assim que estiver pronta, ela aparece aqui.';
}
