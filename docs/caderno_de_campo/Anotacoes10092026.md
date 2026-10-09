Taquara, 9 de Outubro de 2026

- Hoje geramos um grafo de conhecimento do projeto com o graphify, que junta código, documentação e imagens num mapa só para facilitar a navegação pelo repositório. A pasta que ele gera (`graphify-out/`) entrou no `.gitignore`: ela é refeita a cada execução, guarda caminhos desta máquina e passa de 3 MB.
- O grafo também mostrou dois trechos desatualizados no `CLAUDE.md`, e corrigimos os dois. Ele ainda dizia que o app usava login anônimo e não tinha tela de login, mas hoje o login é obrigatório (e-mail e senha ou Google). E dizia que o app continuava no pacote `com.example.*` do template, mas o Android está em `br.com.compy.app` desde a v0.1.0. Agora essa linha só aponta para o checklist de publicação, que é onde esse histórico fica registrado.
