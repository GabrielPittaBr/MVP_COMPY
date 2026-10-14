# COMPY Admin

Aplicação Flutter Web independente do painel administrativo do COMPY. O app
usa o projeto Firebase `compy-tcc` e inicializa Firebase App Check antes de
iniciar autenticação ou qualquer leitura administrativa. Em desenvolvimento,
usa o token debug oficial do Firebase Web apenas em localhost; em release,
usa reCAPTCHA v3.

Para desenvolvimento com App Check debug, use
[`tool/run_local_web.ps1`](tool/run_local_web.ps1). Para build release, use
[`tool/build_web.ps1`](tool/build_web.ps1) com `COMPY_RECAPTCHA_V3_SITE_KEY`
configurada fora do repositório.

Os passos de Firebase Console, Hosting, deploy e rollback estão em
[`docs/admin/firebase-deployment.md`](../docs/admin/firebase-deployment.md).
