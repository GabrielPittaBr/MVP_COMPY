# Tooling Firebase Admin confiável

Este pacote contém comandos privilegiados locais. Ele não é parte do mobile,
do painel Web nem das Cloud Functions implantadas.

## Credenciais

Use somente credenciais externas: Application Default Credentials (ADC) ou
`GOOGLE_APPLICATION_CREDENTIALS` apontando para uma service account fora deste
repositório. Nunca copie credenciais, tokens de App Check ou arquivos `.env`
com segredo para este diretório.

Sem credencial resolvível, o comando falha antes de qualquer mutação com uma
mensagem segura e sem imprimir detalhes internos.

## Bootstrap do primeiro Administrador

```powershell
npm install --prefix tools/firebase-admin
npm run bootstrap-admin --prefix tools/firebase-admin -- --uid <UID> --dry-run
npm run bootstrap-admin --prefix tools/firebase-admin -- --uid <UID>
```

O comando aceita exatamente um UID. Antes de conceder `admin: true`, exige uma
conta habilitada, com e-mail verificado e provider `password`. Ele preserva
outras custom claims, não altera senha/e-mail/providers/verificação e é
idempotente quando a claim já existe. Após a execução real, a pessoa deve sair
e entrar novamente para renovar o ID token.
