# Próximos Passos — MVP Compy

> Documento gerado em 2026-06-29 com base no estado atual do código.

---

## O que já está funcionando

| Área | Status |
|---|---|
| Auth (e-mail/senha + Google) | Completo |
| Roteamento + guards de auth | Completo |
| Splash + fluxo de onboarding | Completo |
| Estrutura das 5 abas (bottom nav) | Completo |
| Home: saudação com nome real do usuário | **Corrigido agora** |
| Home: categorias de esporte, mapa preview | Mock |
| Eventos: lista, detalhe, criar | Firestore ligado (watchAll, create, join) |
| Chat: lista de conversas + sala | Firestore ligado (streams reais) |
| Perfil: visualização | Carrega do Firestore |
| Mapa (flutter_map) | Dados mock de locais |

---

## Prioridade Alta — Bloqueia a usabilidade central

### 1. Avatar real na Home e em todo o app

**Situação atual:** `GreetingHeader` e `ProfileHeader` usam `AppAssets.avatar(userName)`, que gera um placeholder com a inicial do nome. O Firestore já armazena `avatarUrl` no documento `users/{uid}`, mas esse valor nunca é lido na Home.

**O que fazer:**
- Criar um `currentUserSummaryProvider` derivado de `currentProfileProvider` (já existe em `profile_providers.dart`) para expor o `UserSummary` do usuário logado.
- Passar `avatarUrl` para `GreetingHeader` e remover o hardcode de `AppAssets.avatar`.

**Arquivos-chave:**
- `lib/features/home/presentation/widgets/greeting_header.dart`
- `lib/features/home/presentation/providers/home_providers.dart`
- `lib/features/profile/presentation/providers/profile_providers.dart`

---

### 2. Edição de perfil

**Situação atual:** O botão "Editar perfil" em `ProfileHeader` chama `onPressed: () {}` — não faz nada.

**O que fazer:**
- Criar `EditProfilePage` com campos para bio, esportes favoritos e foto.
- Implementar `ProfileRemoteDataSource.update(uid, data)` para escrever no Firestore.
- Permitir upload de foto para Firebase Storage e salvar a URL em `users/{uid}.avatarUrl`.

**Arquivos-chave:**
- `lib/features/profile/presentation/widgets/profile_header.dart:33`
- `lib/features/profile/data/datasources/profile_remote_datasource.dart`

---

### 3. Entrar em evento usando o UID real do usuário logado

**Situação atual:** Em `events_repository_impl.dart:51`, o `userId` passado para `_remote.join()` é `event.creator.id` — um placeholder. O usuário logado não é utilizado.

**O que fazer:**
- Injetar o UID do usuário autenticado (via `authStateProvider`) nos providers de eventos.
- Corrigir `joinEvent` para usar o UID correto.

**Arquivos-chave:**
- `lib/features/events/data/repositories/events_repository_impl.dart:51`
- `lib/features/events/presentation/providers/events_providers.dart`

---

### 4. Criar evento usando os dados reais do criador

**Situação atual:** `CreateEventPage` usa `AuthService` legado para obter o usuário; os dados do criador (`UserSummary`) são preenchidos com placeholders.

**O que fazer:**
- Substituir `AuthService` por `authStateProvider` + `currentProfileProvider`.
- Preencher `creator` no `Event` draft com o `UserSummary` real do usuário logado.

**Arquivos-chave:**
- `lib/features/events/presentation/pages/create_event_page.dart`
- `lib/core/services/auth_service.dart` (candidato a remoção após migração)

---

## Prioridade Média — Completa o fluxo social

### 5. Iniciar nova conversa de chat

**Situação atual:** O usuário não tem como iniciar uma nova conversa — só visualiza as existentes no Firestore.

**O que fazer:**
- Adicionar um FAB ou botão "Nova conversa" em `ConversationsPage`.
- Criar um fluxo de busca de usuários (por username/handle) que abre ou cria um documento em `conversations/` no Firestore.
- Implementar `ChatRemoteDataSource.createConversation(members)`.

---

### 6. Busca funcional

**Situação atual:** `SearchField` existe na Home, mas não conecta a nenhum provider ou rota.

**O que fazer:**
- Definir o escopo da busca (eventos? usuários? locais?).
- Criar `searchProvider` com debounce que consulta Firestore por nome/modalidade.
- Exibir resultados numa tela ou overlay dedicado.

---

### 7. Eventos próximos com geolocalização real

**Situação atual:** `HomeRemoteDataSource.watchNearbyEvents()` ordena por `dateTime`, não por distância. 
A feature de mapa usa dados mock de locais.

**O que fazer:**
- Solicitar permissão de localização com `geolocator`.
- Usar `GeoFlutterFire` ou consulta com Geohash para filtrar eventos por raio no Firestore.
- Conectar o `HomeRepositoryImpl` ao datasource real (flag `kUseFirebaseRepos` já está `true` para eventos).

---

### 8. Sistema de avaliação entre usuários

**Situação atual:** `RatingSummary` e `RatingBreakdown` estão modelados e exibidos no perfil, mas não há forma de registrar avaliações.

**O que fazer:**
- Criar coleção `ratings/{ratingId}` no Firestore com `fromUid`, `toUid`, `score`, `eventId`.
- Acionar o fluxo de avaliação ao encerrar um evento (participante → outros participantes).
- Calcular média e atualizar `users/{uid}.rating` via Cloud Function ou no cliente.

---

## Prioridade Baixa — Polimento e escala

### 9. Push Notifications

- Integrar Firebase Cloud Messaging (FCM).
- Notificar o usuário quando: uma conversa recebe mensagem, alguém entra no seu evento, você recebe uma avaliação.

### 10. Tela de configurações

- O ícone de engrenagem em `GreetingHeader` não navega para lugar nenhum.
- Criar `SettingsPage` com: trocar senha, sair da conta, deletar conta, preferências de notificação.

### 11. Validação e regras do Firestore

- Revisar `firestore.rules` para garantir que:
  - Apenas o dono pode editar `users/{uid}`.
  - Apenas participantes de uma `conversation` podem ler/escrever mensagens.
  - O campo `remainingSpots` só diminui (impedir fraude no join).

### 12. Paginação

- `EventsListPage` e `ConversationsPage` carregam tudo de uma vez.
- Adicionar paginação com `startAfterDocument` nos datasources do Firestore.

---

## Débito técnico imediato

| Item | Local |
|---|---|
| `AuthService` legado ainda importado em `create_event_page.dart` | `lib/core/services/auth_service.dart` |
| `InMemoryEventsStore.currentUser` hardcoded como placeholder no join | `lib/features/events/data/datasources/in_memory_events_store.dart` |
| `ProfileRemoteDataSource` só faz `fetchById` — sem update | `lib/features/profile/data/datasources/profile_remote_datasource.dart` |
| Home usa mock para eventos próximos mesmo com Firebase ligado | `lib/features/home/data/repositories/home_repository_impl.dart` |