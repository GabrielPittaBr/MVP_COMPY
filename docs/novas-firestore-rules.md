# O que mudou na versão 2 do firestore-rules, por linha da tabela

| Coleção                  | Antes                         | Agora                                                                                                                                                                                                                                                                                                |
| ------------------------ | ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| usernames                | só create                     | + update quando resource.data.uid == request.auth.uid — destrava o re-cadastro do item 3 da tarefa 5. read: if true mantido, agora com o comentário explicando que é decisão (checagem pré-login), não resquício                                                                                     |
| places                   | read: if signedIn()           | **regra removida na tarefa 6.** O catálogo passou a viver em código (`SportPlace.all`) e o `PlacesRemoteDataSource` foi apagado: nada aponta mais para a coleção, que volta ao deny-by-default. No lugar da regra ficou só o comentário dizendo onde os locais moram                                                                                                                                       |
| conversations / messages | read, write: if signedIn()    | leitura só para request.auth.uid in resource.data.members; create exige incluir a si mesmo e 2 membros; update só mexe em lastMessage/lastMessageAt/unreadCounts (members vira imutável); mensagens validam associação por get() no pai, senderId tem que ser o próprio uid, e update/delete negados |
| events                   | create, update: if signedIn() | create exige creator.id == uid e vagas coerentes; update tem dois caminhos: criador edita (sem trocar o dono) ou é um join — hasOnly(['participants','remainingSpots']), participante acrescentado no fim tem que ser o próprio uid e remainingSpots cai exatamente 1. Isso fecha a fraude do join   |
| users                    | dono cria/edita               | + hasOnly na lista de campos, id == userId, limites de name/handle e favoriteSports como lista de no máximo 8                                                                                                                                                                                        |
| ratings                  | não existia                   | escrita do zero: read: if false (D13), create só com fromUid == uid e formato validado — stars inteiro 1–5, targetType num conjunto fechado, comentário ≤500 e obrigatório abaixo de 3 estrelas (D12); update/delete negados                                                                         |

## Duas coisas que você precisa saber antes de publicar

### 1. Envio de mensagem

Isso quebra o envio de mensagem hoje. ChatRepositoryImpl.sendMessage() manda senderId: InMemoryChatStore.currentUserId ('u_joao', chat_repository_impl.dart:114). Com a regra nova, o Firestore devolve PERMISSION_DENIED em vez de gravar com identidade falsa. A aba já estava inútil (achado 5), mas antes falhava em silêncio e agora falha alto — o conserto é a fatia 1 da tarefa 9. Se quiser publicar antes disso, o caminho é fazer a fatia 1 junto.

### 2. O que deixei de propósito sem validar, com comentário no arquivo

* handle e createdAt continuam reescrevíveis pelo dono. _writeUserProfile regrava os dois em batch no re-cadastro, e regra nenhuma enxerga as outras escritas do mesmo batch — travar isso quebraria o cadastro que funciona hoje.
* O email continua legível por qualquer autenticado (contraria a RN-06). A correção é mover para users/{uid}/private/contact, que é mudança de código, não de regra.
* Três TODO marcados: participantIds no join (tarefa 12), a exceção do encerramento automático (tarefa 14) e os get() que exigiriam evento encerrado + autor participante para criar rating (tarefa 14) — todos dependem de campos que ainda não existem.

O CLAUDE.md ainda diz que firestore.rules é allow read, write: if false; posso corrigir essa linha se quiser. E vale rodar as regras de events e conversations no emulador antes de publicar — errar o affectedKeys() trava o join em produção.
