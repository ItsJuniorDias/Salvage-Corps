# Publicando no itch.io (macOS)

O build do itch é a versão Mac Catalyst do jogo, compilada com o flag `ITCH`:
sem Game Center e sem push (ambos só funcionam via App Store/TestFlight), então
o modo Duelos fica oculto. A campanha single-player funciona normalmente.

## 1. Gerar o build

```bash
itch/build_mac.sh
```

Saída: `itch/dist/SalvageCorps-mac-<versão>.zip`.

- **Com certificado "Developer ID Application"** no keychain → o script assina,
  notariza e grampeia o ticket. O app abre sem aviso.
  - Criar o certificado: Xcode › Settings › Accounts › Manage Certificates › `+`
    › Developer ID Application (só o Account Holder do time consegue).
  - Salvar credenciais do notarytool uma vez (use uma senha de app de
    appleid.apple.com):
    `xcrun notarytool store-credentials salvage-notary --apple-id <email> --team-id 968FPR7Y35`
- **Sem o certificado** → build com assinatura ad-hoc. Na primeira vez, o jogador
  precisa ir em Ajustes do Sistema › Privacidade e Segurança › "Abrir Mesmo Assim".
  Coloque esse aviso na página do itch.

## 2. Criar a página no itch

1. itch.io › Dashboard › Create new project.
2. Kind of project: **Downloadable**. Anote a URL (`<usuario>/<jogo>`).
3. Preencha capa (630×500), screenshots, descrição, tags (deckbuilder, roguelike,
   horror, ww1) e preço.

## 3. Enviar

Manual: suba o `.zip` na página e marque a plataforma **macOS**.

Ou com o [butler](https://itch.io/docs/butler/) (recomendado para atualizações):

```bash
butler login
ITCH_TARGET=<usuario>/<jogo> itch/build_mac.sh --upload
```
