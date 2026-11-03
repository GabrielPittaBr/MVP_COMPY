Taquara, 3 de Novembro de 2026


- Hoje corrigimos o login com Google nos APKs compilados nesta máquina (issue #33). Eles saem assinados com a chave de debug daqui, porque a chave oficial não está nesta máquina, e a impressão SHA-1 dessa chave só estava cadastrada no app antigo `com.example.mvp_compy`, não no `br.com.compy.app`. Por isso o Google recusava o login com `ApiException: 10` e o app mostrava "Login com Google indisponível nesta versão do app.". Cadastramos a SHA-1 e a SHA-256 no app certo do Firebase e baixamos o `google-services.json` de novo, que agora traz um cliente OAuth para essa chave. Registramos no checklist de publicação o cuidado de cadastrar sempre no pacote novo.
