# Push Notifications — Setup Apple Developer

O código Swift está pronto. Falta o setup do Apple Developer Portal + Xcode
(coisas que só você acessa). São **~10 minutos** de cliques em interfaces web.

## Contexto

Game Center Turn-Based **envia push automaticamente** quando é vez do player.
Não precisamos de servidor APNs próprio, backend, ou push tokens gerenciados.
Precisamos apenas de:

1. ✅ **Feito (código)**: pedir permissão, registrar device, tratar taps
2. ⚠️ **Pendente (você)**: habilitar capability no App ID + Xcode

---

## Passo 1 — Apple Developer Portal (~5 min)

Abre https://developer.apple.com/account/resources/identifiers/

1. Clica no App ID `alexandrejunior.Salvage-Corps`
2. Rola até **Capabilities**
3. Marca ☑️ **Push Notifications**
4. Salva (botão "Save" no topo direito)

Isso habilita APNs pra esse App ID. Não precisa gerar APNs Key porque não
vamos enviar push customizado — Game Center gerencia.

---

## Passo 2 — Xcode (~3 min)

Abre o projeto Salvage Corps no Xcode:

1. Clica no projeto no navigator → target **Salvage Corps**
2. Aba **Signing & Capabilities**
3. Clica **+ Capability** (topo esquerdo)
4. Adiciona **Push Notifications**
5. Adiciona **Background Modes**
6. Dentro de Background Modes, marca ☑️ **Remote notifications**

Xcode vai atualizar automaticamente o `Salvage Corps.entitlements` — o
código já tem `aps-environment = development` pré-configurado, então
provavelmente vai passar direto.

---

## Passo 3 — Testar (~2 min)

1. **Build & Run** no seu iPhone físico (simulator NÃO recebe push)
2. Vai pro modo Duels
3. Deve aparecer um banner laranja: **"AVISO EM TEMPO REAL — HABILITAR NOTIFICAÇÕES"**
4. Toca em habilitar → iOS mostra prompt nativo
5. Concede permissão
6. Banner some
7. Vai em **Ajustes do iOS → Salvage Corps → Notificações** — deve estar habilitado
8. Peça pro seu irmão jogar o turno dele em um match → você deve receber notification

---

## Troubleshooting

### "Provisioning profile doesn't include aps-environment entitlement"

Solução: no Xcode, vai em **Signing & Capabilities** e clica no botão
**"Try Again"** ao lado de "Automatically manage signing". Xcode regenera
o profile incluindo APNs.

### Notification chega mas não abre no match certo

Payload do Game Center pode variar entre iOS versões. O código tenta extrair
`userInfo["gameCenter"]["matchID"]` — se não conseguir, cai no menu de Duels.
Ainda funcional, só menos direto. Podemos ajustar depois se você notar.

### Banner não aparece no DuelsMenuView

Ver `PushNotificationsManager.authorizationStatus` no Xcode debugger.
Se estiver `.authorized`, é comportamento correto (banner some quando ok).

### Não quero pedir permissão logo de cara

O banner NÃO pede permissão sozinho — só oferece. Player precisa tocar
"HABILITAR" pra o iOS mostrar o prompt. Se não tocar, ficamos em
`.notDetermined` e banner continua ali.

---

## Comportamento esperado por estado

| Estado | Banner mostra? | O que faz |
|--------|---------------|-----------|
| `.notDetermined` | Sim, laranja | Toca → pede permissão iOS |
| `.denied` | Sim, laranja com bell.slash | Toca → abre Settings do app |
| `.authorized` | Não (some) | — |
| `.provisional` | Não | — |
| `.ephemeral` | Não | — |

---

## Próximos passos (opcional)

- **Provisional authorization** (`.provisional`): iOS 12+ permite mandar
  notifications "quietly" (só na Notification Center, sem banner) sem
  pedir permissão. Bom pra low-friction, mas menos visível. Não implementado.
- **Notifications customizadas locais**: alertas tipo "3 duelos aguardando
  há mais de 24h" ao abrir o app. Precisa `UNMutableNotificationContent` +
  `UNTimeIntervalNotificationTrigger`.
- **Rich notifications**: preview do estado do match (imagem, actions
  inline "Play turn" / "Forfeit"). Requer `Notification Service Extension`
  target no Xcode. Escopo grande.
