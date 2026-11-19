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
