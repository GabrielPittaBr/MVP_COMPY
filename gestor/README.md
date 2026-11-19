# COMPY · Painel do Local (protótipo visual)

Aplicação Flutter Web do Painel do Local, a plataforma da equipe dos locais
esportivos parceiros. Esta versão é só o visual: todos os dados são fictícios
(Arena Exemplo, 5 quadras de areia, quinta, 19/11, às 18:40), ficam em memória
e somem ao recarregar a página. Não há Firebase, login de verdade nem Cloud
Functions ainda.

Os requisitos e as telas de referência estão em
[`docs/gestores/`](../docs/gestores/README.md). Como no painel admin, `gestor/`
não importa código do app nem do admin.

```powershell
flutter pub get
flutter run -d chrome
```

Na tela de entrada, a caixa "Demonstração" escolhe o papel (Atendente ou
Proprietário). No menu, "Ver como..." troca de papel sem sair.

## No ar

https://compy-tcc-gestor.web.app, o terceiro site do Hosting no projeto
`compy-tcc` (alvo `gestor` no `firebase.json`). Para publicar de novo, a
partir da raiz do repositório:

```powershell
cd gestor; flutter build web --release; cd ..
firebase deploy --only hosting:gestor
```

O site manda `X-Robots-Tag: noindex`, para a demonstração não aparecer em
buscadores.

## O que mudou em relação às telas desenhadas

O pedido foi simplificar o que estava com muito conteúdo junto:

- **Hoje:** no lugar da grade com uma célula de texto por quadra e hora, cada
  quadra aparece desenhada, vista de cima, com uma plaqueta do que acontece
  nela. Um seletor de horário (agora, 19h, 20h...) mostra as quadras mais
  tarde, e tocar numa quadra abre as ações daquele horário.
- **Agenda:** horário livre fica em branco (só um "+"), e o que dura mais de
  uma hora vira um bloco só. No celular, uma quadra por vez.
- **Formulários:** a quadra é escolhida em quadrinhas desenhadas, com as
  ocupadas riscadas. A nova reserva segue a conversa: quando, qual quadra e
  quem.
- **Telas do proprietário:** Quadras e Perfil viraram abas curtas; a tabela de
  permissões da Equipe virou um resumo por papel, com a tabela recolhida.
- O que é da 2ª versão (Evento do Local, stories, resultados) aparece com o
  selo "2ª versão".
