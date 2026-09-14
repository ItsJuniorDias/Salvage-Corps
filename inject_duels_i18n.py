#!/usr/bin/env python3
"""
Injeta as strings novas do modo Duelos no Localizable.xcstrings.

Preserva strings existentes (não substitui — só adiciona se a chave for nova
ou se explicitamente marcada como update). Idempotente: rodar 2x não muda nada
depois da 1a rodada.
"""
import json
import sys
from pathlib import Path

XCSTRINGS_PATH = Path("Salvage Corps/Localizable.xcstrings")

# Dicionário: chave → { pt-BR, en, es }
# Ordem das chaves aqui não importa — organizado por seção pra facilitar review.
STRINGS = {
    # ---- MENU (RootView button) ----
    "menu.duels.title": {
        "pt-BR": "DUELOS · PVP",
        "en":    "DUELS · PVP",
        "es":    "DUELOS · PVP",
    },
    "menu.duels.subtitle": {
        "pt-BR": "Turno-a-turno via Game Center",
        "en":    "Turn-by-turn via Game Center",
        "es":    "Turno por turno vía Game Center",
    },
    "menu.duels.subtitle_auth_error": {
        "pt-BR": "Toque pra ver status do Game Center",
        "en":    "Tap to see Game Center status",
        "es":    "Toca para ver el estado de Game Center",
    },

    # ---- DUELS MENU (hub) ----
    "duel.menu.title": {
        "pt-BR": "DUELOS",
        "en":    "DUELS",
        "es":    "DUELOS",
    },
    "duel.menu.subtitle": {
        "pt-BR": "PVP · TURN-BASED · GAME CENTER",
        "en":    "PVP · TURN-BASED · GAME CENTER",
        "es":    "PVP · POR TURNOS · GAME CENTER",
    },
    "duel.menu.logged_as": {
        "pt-BR": "LOGADO COMO",
        "en":    "SIGNED IN AS",
        "es":    "CONECTADO COMO",
    },
    "duel.menu.new_duel": {
        "pt-BR": "NOVO DUELO",
        "en":    "NEW DUEL",
        "es":    "NUEVO DUELO",
    },
    "duel.menu.new_duel_subtitle": {
        "pt-BR": "Adversário aleatório",
        "en":    "Random opponent",
        "es":    "Adversario aleatorio",
    },
    "duel.menu.invite_friend": {
        "pt-BR": "CONVIDAR",
        "en":    "INVITE",
        "es":    "INVITAR",
    },
    "duel.menu.invite_friend_subtitle": {
        "pt-BR": "Jogar com alguém agora",
        "en":    "Play with someone now",
        "es":    "Jugar con alguien ahora",
    },
    "duel.matchmaker.invite_message": {
        "pt-BR": "Vem duelar comigo em Salvage Corps!",
        "en":    "Come duel with me in Salvage Corps!",
        "es":    "¡Ven a duelar conmigo en Salvage Corps!",
    },
    "duel.menu.my_duels": {
        "pt-BR": "MEUS DUELOS",
        "en":    "MY DUELS",
        "es":    "MIS DUELOS",
    },
    "duel.menu.loading": {
        "pt-BR": "Carregando…",
        "en":    "Loading…",
        "es":    "Cargando…",
    },
    "duel.menu.no_active": {
        "pt-BR": "Nenhum duelo ativo.",
        "en":    "No active duels.",
        "es":    "No hay duelos activos.",
    },
    "duel.menu.tap_new_hint": {
        "pt-BR": "Toque em NOVO DUELO pra começar.",
        "en":    "Tap NEW DUEL to start.",
        "es":    "Toca NUEVO DUELO para empezar.",
    },
    "duel.menu.back_to_menu": {
        "pt-BR": "Menu",
        "en":    "Menu",
        "es":    "Menú",
    },
    "duel.menu.my_deck": {
        "pt-BR": "MEU DECK",
        "en":    "MY DECK",
        "es":    "MI MAZO",
    },
    # Format: current N of max — %1$lld/%2$lld
    "duel.menu.my_deck_subtitle %lld %lld": {
        "pt-BR": "%1$lld/%2$lld cartas · edite suas cópias",
        "en":    "%1$lld/%2$lld cards · edit your copies",
        "es":    "%1$lld/%2$lld cartas · edita tus copias",
    },

    # ---- DECK BUILDER (Fase 8) ----
    "duel.deck.builder_title": {
        "pt-BR": "MEU DECK",
        "en":    "MY DECK",
        "es":    "MI MAZO",
    },
    "duel.deck.builder_subtitle": {
        "pt-BR": "MONTE 15 CARTAS · MÁX 2 CÓPIAS POR CARTA",
        "en":    "BUILD 15 CARDS · MAX 2 COPIES PER CARD",
        "es":    "ARMA 15 CARTAS · MÁX 2 COPIAS POR CARTA",
    },
    # Format: current N / max — %1$lld/%2$lld
    "duel.deck.count_label %lld %lld": {
        "pt-BR": "%1$lld/%2$lld",
        "en":    "%1$lld/%2$lld",
        "es":    "%1$lld/%2$lld",
    },
    "duel.deck.need_more %lld": {
        "pt-BR": "faltam %lld",
        "en":    "%lld more needed",
        "es":    "faltan %lld",
    },
    "duel.deck.need_less %lld": {
        "pt-BR": "%lld a mais",
        "en":    "%lld too many",
        "es":    "%lld de más",
    },
    "duel.deck.pool_title": {
        "pt-BR": "CARTAS DISPONÍVEIS",
        "en":    "AVAILABLE CARDS",
        "es":    "CARTAS DISPONIBLES",
    },
    "duel.deck.save": {
        "pt-BR": "SALVAR",
        "en":    "SAVE",
        "es":    "GUARDAR",
    },
    "duel.deck.reset_default": {
        "pt-BR": "RESETAR PADRÃO",
        "en":    "RESET DEFAULT",
        "es":    "RESTABLECER",
    },
    "duel.deck.saved_toast": {
        "pt-BR": "DECK SALVO",
        "en":    "DECK SAVED",
        "es":    "MAZO GUARDADO",
    },
    "duel.deck.back": {
        "pt-BR": "Duelos",
        "en":    "Duels",
        "es":    "Duelos",
    },

    # ---- AWAITING OPPONENT DECK (Fase 8) ----
    "duel.deck.awaiting_title": {
        "pt-BR": "AGUARDANDO ADVERSÁRIO",
        "en":    "WAITING FOR OPPONENT",
        "es":    "ESPERANDO AL ADVERSARIO",
    },
    "duel.deck.awaiting_message": {
        "pt-BR": "O adversário precisa abrir o app e escolher o deck dele. Você recebe uma notificação quando o duelo começar.",
        "en":    "The opponent needs to open the app and pick their deck. You'll get a notification when the duel begins.",
        "es":    "El adversario necesita abrir la app y elegir su mazo. Recibirás una notificación cuando empiece el duelo.",
    },

    # ---- RANKED / RATING (Fase 9) ----
    "duel.menu.leaderboard": {
        "pt-BR": "GAME CENTER",
        "en":    "GAME CENTER",
        "es":    "GAME CENTER",
    },
    "duel.menu.leaderboard_subtitle": {
        "pt-BR": "Ranking e troféus",
        "en":    "Ranking & trophies",
        "es":    "Ranking y logros",
    },
    # Tiers — nomes de patente militares em pt-BR (originais em pt-BR pra manter tema)
    "duel.rank.recruta": {
        "pt-BR": "RECRUTA",
        "en":    "RECRUIT",
        "es":    "RECLUTA",
    },
    "duel.rank.soldado": {
        "pt-BR": "SOLDADO",
        "en":    "SOLDIER",
        "es":    "SOLDADO",
    },
    "duel.rank.sargento": {
        "pt-BR": "SARGENTO",
        "en":    "SERGEANT",
        "es":    "SARGENTO",
    },
    "duel.rank.tenente": {
        "pt-BR": "TENENTE",
        "en":    "LIEUTENANT",
        "es":    "TENIENTE",
    },
    "duel.rank.capitao": {
        "pt-BR": "CAPITÃO",
        "en":    "CAPTAIN",
        "es":    "CAPITÁN",
    },
    "duel.rank.oficial": {
        "pt-BR": "OFICIAL",
        "en":    "OFFICER",
        "es":    "OFICIAL",
    },
    # Format: proximo tier começa em %lld pts
    "duel.rank.next_tier_at %lld": {
        "pt-BR": "próximo em %lld",
        "en":    "next at %lld",
        "es":    "siguiente en %lld",
    },
    "duel.rank.max_tier": {
        "pt-BR": "patente máxima",
        "en":    "max rank",
        "es":    "rango máximo",
    },
    "duel.rank.promoted": {
        "pt-BR": "PROMOVIDO A",
        "en":    "PROMOTED TO",
        "es":    "ASCENDIDO A",
    },
    "duel.rank.demoted": {
        "pt-BR": "REBAIXADO A",
        "en":    "DEMOTED TO",
        "es":    "DEGRADADO A",
    },
    "duel.rank.no_matches_yet": {
        "pt-BR": "sem partidas ainda",
        "en":    "no matches yet",
        "es":    "sin partidas aún",
    },

    # ---- W/L RECORD (Fase 10) ----
    "duel.rank.wins_short %lld": {
        "pt-BR": "%lldV",
        "en":    "%lldW",
        "es":    "%lldV",
    },
    "duel.rank.losses_short %lld": {
        "pt-BR": "%lldD",
        "en":    "%lldL",
        "es":    "%lldD",
    },
    "duel.rank.winrate %lld": {
        "pt-BR": "%lld%%",
        "en":    "%lld%%",
        "es":    "%lld%%",
    },

    # ---- HISTORY (Fase 10) ----
    "duel.menu.history": {
        "pt-BR": "HISTÓRICO",
        "en":    "HISTORY",
        "es":    "HISTORIAL",
    },
    "duel.menu.history_subtitle %lld": {
        "pt-BR": "%lld partidas",
        "en":    "%lld matches",
        "es":    "%lld partidas",
    },
    "duel.menu.history_subtitle_empty": {
        "pt-BR": "Nenhuma partida ainda",
        "en":    "No matches yet",
        "es":    "Aún no hay partidas",
    },
    "duel.history.title": {
        "pt-BR": "HISTÓRICO",
        "en":    "HISTORY",
        "es":    "HISTORIAL",
    },
    "duel.history.subtitle %lld": {
        "pt-BR": "ÚLTIMAS %lld PARTIDAS",
        "en":    "LAST %lld MATCHES",
        "es":    "ÚLTIMAS %lld PARTIDAS",
    },
    "duel.history.empty_title": {
        "pt-BR": "Nenhuma partida registrada",
        "en":    "No matches recorded",
        "es":    "Sin partidas registradas",
    },
    "duel.history.empty_message": {
        "pt-BR": "Jogue algumas partidas classificatórias — o histórico das últimas 100 aparece aqui.",
        "en":    "Play some ranked matches — history of the last 100 shows up here.",
        "es":    "Juega algunas partidas clasificatorias — el historial de las últimas 100 aparecerá aquí.",
    },

    # ---- AUTH / DIAGNOSTIC ----
    "duel.auth.not_authenticated": {
        "pt-BR": "Não autenticado",
        "en":    "Not authenticated",
        "es":    "No autenticado",
    },
    "duel.auth.apple_error_label": {
        "pt-BR": "ERRO DA APPLE",
        "en":    "APPLE ERROR",
        "es":    "ERROR DE APPLE",
    },
    "duel.auth.retry": {
        "pt-BR": "TENTAR AUTENTICAR NOVAMENTE",
        "en":    "TRY AUTHENTICATING AGAIN",
        "es":    "INTENTAR AUTENTICAR DE NUEVO",
    },
    "duel.auth.checklist_title": {
        "pt-BR": "CHECKLIST",
        "en":    "CHECKLIST",
        "es":    "LISTA DE VERIFICACIÓN",
    },
    "duel.auth.check_signin_title": {
        "pt-BR": "1. Logado no Game Center?",
        "en":    "1. Signed into Game Center?",
        "es":    "1. ¿Conectado a Game Center?",
    },
    "duel.auth.check_signin_detail": {
        "pt-BR": "Ajustes → Game Center",
        "en":    "Settings → Game Center",
        "es":    "Ajustes → Game Center",
    },
    "duel.auth.check_capability_title": {
        "pt-BR": "2. Capability Game Center no target?",
        "en":    "2. Game Center capability enabled?",
        "es":    "2. ¿Capacidad Game Center habilitada?",
    },
    "duel.auth.check_capability_detail": {
        "pt-BR": "Xcode → Signing & Capabilities",
        "en":    "Xcode → Signing & Capabilities",
        "es":    "Xcode → Signing & Capabilities",
    },
    "duel.auth.check_asc_title": {
        "pt-BR": "3. Bundle ID registrado no App Store Connect?",
        "en":    "3. Bundle ID registered in App Store Connect?",
        "es":    "3. ¿Bundle ID registrado en App Store Connect?",
    },
    "duel.auth.check_asc_detail": {
        "pt-BR": "appstoreconnect.apple.com → My Apps → +",
        "en":    "appstoreconnect.apple.com → My Apps → +",
        "es":    "appstoreconnect.apple.com → My Apps → +",
    },

    # ---- MATCH STATUS ----
    "duel.status.your_turn": {
        "pt-BR": "Sua vez",
        "en":    "Your turn",
        "es":    "Tu turno",
    },
    # Format: "Vez de <name>" — %@ is opponent display name
    "duel.status.opponent_turn %@": {
        "pt-BR": "Vez de %@",
        "en":    "%@'s turn",
        "es":    "Turno de %@",
    },
    "duel.status.waiting_opponent": {
        "pt-BR": "Aguardando adversário",
        "en":    "Waiting for opponent",
        "es":    "Esperando al adversario",
    },
    "duel.status.matchmaking": {
        "pt-BR": "Procurando adversário",
        "en":    "Finding opponent",
        "es":    "Buscando adversario",
    },
    "duel.status.ended": {
        "pt-BR": "Encerrado",
        "en":    "Ended",
        "es":    "Finalizado",
    },
    "duel.status.unknown": {
        "pt-BR": "Status desconhecido",
        "en":    "Unknown status",
        "es":    "Estado desconocido",
    },

    # ---- COMBAT HEADER ----
    # Format: "DUELO · TURNO 5" — %lld is turn number
    "duel.combat.turn_label %lld": {
        "pt-BR": "DUELO · TURNO %lld",
        "en":    "DUEL · TURN %lld",
        "es":    "DUELO · TURNO %lld",
    },
    "duel.combat.my_turn": {
        "pt-BR": "SEU TURNO",
        "en":    "YOUR TURN",
        "es":    "TU TURNO",
    },
    "duel.combat.opponent_turn": {
        "pt-BR": "TURNO DO ADVERSÁRIO",
        "en":    "OPPONENT'S TURN",
        "es":    "TURNO DEL ADVERSARIO",
    },
    "duel.combat.ended": {
        "pt-BR": "ENCERRADO",
        "en":    "ENDED",
        "es":    "FINALIZADO",
    },
    "duel.combat.back_to_duels": {
        "pt-BR": "Duelos",
        "en":    "Duels",
        "es":    "Duelos",
    },

    # ---- COMBAT STATS / PILES ----
    "duel.combat.stat.hp": {
        "pt-BR": "HP",
        "en":    "HP",
        "es":    "HP",
    },
    "duel.combat.stat.moral": {
        "pt-BR": "MORAL",
        "en":    "MORALE",
        "es":    "MORAL",
    },
    "duel.combat.stat.block": {
        "pt-BR": "BLOCK",
        "en":    "BLOCK",
        "es":    "BLOQUEO",
    },
    "duel.combat.stat.energy": {
        "pt-BR": "ENERGIA",
        "en":    "ENERGY",
        "es":    "ENERGÍA",
    },
    "duel.combat.stat.hand": {
        "pt-BR": "MÃO",
        "en":    "HAND",
        "es":    "MANO",
    },
    "duel.combat.stat.deck": {
        "pt-BR": "DECK",
        "en":    "DECK",
        "es":    "MAZO",
    },
    "duel.combat.stat.discard_short": {
        "pt-BR": "DESC",
        "en":    "DISC",
        "es":    "DESC",
    },
    "duel.combat.pile.deck": {
        "pt-BR": "DECK",
        "en":    "DECK",
        "es":    "MAZO",
    },
    "duel.combat.pile.discard": {
        "pt-BR": "DESCARTE",
        "en":    "DISCARD",
        "es":    "DESCARTE",
    },
    "duel.combat.pile.exile": {
        "pt-BR": "EXÍLIO",
        "en":    "EXILE",
        "es":    "EXILIO",
    },
    "duel.combat.pile.fatigue": {
        "pt-BR": "FADIGA",
        "en":    "FATIGUE",
        "es":    "FATIGA",
    },

    # ---- COMBAT ACTIONS ----
    "duel.combat.end_turn": {
        "pt-BR": "TERMINAR",
        "en":    "END TURN",
        "es":    "TERMINAR",
    },
    "duel.combat.wait": {
        "pt-BR": "AGUARDE",
        "en":    "WAIT",
        "es":    "ESPERA",
    },
    "duel.combat.empty_hand": {
        "pt-BR": "Sua mão está vazia",
        "en":    "Your hand is empty",
        "es":    "Tu mano está vacía",
    },
    "duel.combat.need_hand_target": {
        "pt-BR": "Precisa de outra carta na mão como alvo",
        "en":    "Need another card in hand as target",
        "es":    "Necesitas otra carta en la mano como objetivo",
    },
    "duel.combat.tap_other_target": {
        "pt-BR": "TOQUE OUTRA CARTA PRA ESCOLHER ALVO",
        "en":    "TAP ANOTHER CARD TO CHOOSE TARGET",
        "es":    "TOCA OTRA CARTA PARA ELEGIR OBJETIVO",
    },
    "duel.combat.cancel_selection": {
        "pt-BR": "CANCELAR",
        "en":    "CANCEL",
        "es":    "CANCELAR",
    },

    # ---- COMBAT DIALOGS ----
    "duel.combat.forfeit_title": {
        "pt-BR": "Desistir do duelo?",
        "en":    "Forfeit the duel?",
        "es":    "¿Rendirse en el duelo?",
    },
    "duel.combat.forfeit_message": {
        "pt-BR": "Você perde o duelo. O adversário vence.",
        "en":    "You lose the duel. Your opponent wins.",
        "es":    "Pierdes el duelo. Tu adversario gana.",
    },
    "duel.combat.forfeit_confirm": {
        "pt-BR": "Desistir",
        "en":    "Forfeit",
        "es":    "Rendirse",
    },
    "duel.combat.cancel": {
        "pt-BR": "Cancelar",
        "en":    "Cancel",
        "es":    "Cancelar",
    },
    "duel.combat.invalid_action": {
        "pt-BR": "Ação inválida",
        "en":    "Invalid action",
        "es":    "Acción no válida",
    },
    "duel.combat.ok": {
        "pt-BR": "OK",
        "en":    "OK",
        "es":    "OK",
    },

    # ---- RECAP / EVENTS ----
    "duel.recap.title": {
        "pt-BR": "TURNO ANTERIOR DO ADVERSÁRIO",
        "en":    "OPPONENT'S PREVIOUS TURN",
        "es":    "TURNO ANTERIOR DEL ADVERSARIO",
    },
    "duel.combat.events_current_turn": {
        "pt-BR": "EVENTOS DO TURNO ATUAL",
        "en":    "EVENTS THIS TURN",
        "es":    "EVENTOS DEL TURNO ACTUAL",
    },
    "duel.combat.no_events_yet": {
        "pt-BR": "(sem eventos ainda no turno)",
        "en":    "(no events yet this turn)",
        "es":    "(sin eventos en el turno aún)",
    },

    # ---- ENDGAME ----
    "duel.combat.victory": {
        "pt-BR": "VITÓRIA",
        "en":    "VICTORY",
        "es":    "VICTORIA",
    },
    "duel.combat.defeat": {
        "pt-BR": "DERROTA",
        "en":    "DEFEAT",
        "es":    "DERROTA",
    },
    "duel.combat.victory_message": {
        "pt-BR": "Você conteve o adversário.",
        "en":    "You contained your opponent.",
        "es":    "Contuviste a tu adversario.",
    },
    "duel.combat.defeat_message": {
        "pt-BR": "O adversário te derrotou.",
        "en":    "Your opponent defeated you.",
        "es":    "Tu adversario te derrotó.",
    },
    "duel.combat.back_to_duels_button": {
        "pt-BR": "VOLTAR AOS DUELOS",
        "en":    "BACK TO DUELS",
        "es":    "VOLVER A LOS DUELOS",
    },

    # ---- MATCHMAKING WAITING ----
    "duel.matchmaking.title": {
        "pt-BR": "PROCURANDO ADVERSÁRIO",
        "en":    "FINDING OPPONENT",
        "es":    "BUSCANDO ADVERSARIO",
    },
    "duel.matchmaking.message": {
        "pt-BR": "Aguardando o Game Center encontrar um oponente.",
        "en":    "Waiting for Game Center to find an opponent.",
        "es":    "Esperando a que Game Center encuentre un oponente.",
    },
    "duel.matchmaking.back": {
        "pt-BR": "VOLTAR",
        "en":    "BACK",
        "es":    "VOLVER",
    },

    # ---- PLAYER LABELS ----
    "duel.player.you": {
        "pt-BR": "Você",
        "en":    "You",
        "es":    "Tú",
    },
    "duel.player.opponent": {
        "pt-BR": "Adversário",
        "en":    "Opponent",
        "es":    "Adversario",
    },
    "duel.player.opponent_default_name": {
        "pt-BR": "Adversário",
        "en":    "Opponent",
        "es":    "Adversario",
    },

    # ---- STATUS EFFECTS (nomes por extenso, usados no recap) ----
    "duel.status_effect.block": {
        "pt-BR": "Bloqueio",
        "en":    "Block",
        "es":    "Bloqueo",
    },
    "duel.status_effect.fear": {
        "pt-BR": "Medo",
        "en":    "Fear",
        "es":    "Miedo",
    },
    "duel.status_effect.fatigue": {
        "pt-BR": "Fadiga",
        "en":    "Fatigue",
        "es":    "Fatiga",
    },
    "duel.status_effect.corruption": {
        "pt-BR": "Corrupção",
        "en":    "Corruption",
        "es":    "Corrupción",
    },
    "duel.status_effect.skip_next_turn": {
        "pt-BR": "Skip",
        "en":    "Skip",
        "es":    "Salto",
    },

    # Também garante que a chave já usada em CombatView/UpgradeCardView tem tradução
    "status.skip_next_turn": {
        "pt-BR": "Turno pulado",
        "en":    "Turn skipped",
        "es":    "Turno saltado",
    },

    # ---- LOG EVENTS ----
    "duel.event.duel_started": {
        "pt-BR": "Duelo começou",
        "en":    "Duel started",
        "es":    "Duelo empezó",
    },
    # Format: turn number %lld, who %@
    "duel.event.turn_started %lld %@": {
        "pt-BR": "Turno %1$lld — %2$@",
        "en":    "Turn %1$lld — %2$@",
        "es":    "Turno %1$lld — %2$@",
    },
    # Format: who %@, card name %@
    "duel.event.card_played %@ %@": {
        "pt-BR": "%1$@ jogou %2$@",
        "en":    "%1$@ played %2$@",
        "es":    "%1$@ jugó %2$@",
    },
    # Format: who %@, amount %lld
    "duel.event.damage_dealt %@ %lld": {
        "pt-BR": "%1$@ tomou %2$lld de dano",
        "en":    "%1$@ took %2$lld damage",
        "es":    "%1$@ recibió %2$lld de daño",
    },
    # Format: blocked amount %lld
    "duel.event.damage_blocked_part %lld": {
        "pt-BR": " (%lld bloqueado)",
        "en":    " (%lld blocked)",
        "es":    " (%lld bloqueado)",
    },
    # Format: who %@, delta (assinado) %lld
    "duel.event.moral_gained %@ %lld": {
        "pt-BR": "%1$@ ganhou %2$lld de moral",
        "en":    "%1$@ gained %2$lld morale",
        "es":    "%1$@ ganó %2$lld de moral",
    },
    "duel.event.moral_lost %@ %lld": {
        "pt-BR": "%1$@ perdeu %2$lld de moral",
        "en":    "%1$@ lost %2$lld morale",
        "es":    "%1$@ perdió %2$lld de moral",
    },
    # Format: who %@, delta (positive means loss in negation) %lld
    "duel.event.hp_change %@ %lld": {
        "pt-BR": "%1$@ HP %2$lld",
        "en":    "%1$@ HP %2$lld",
        "es":    "%1$@ HP %2$lld",
    },
    "duel.event.block_gained %@ %lld": {
        "pt-BR": "%1$@ ganhou %2$lld de bloqueio",
        "en":    "%1$@ gained %2$lld block",
        "es":    "%1$@ ganó %2$lld de bloqueo",
    },
    # Format: who %@, count %lld, status name %@
    "duel.event.status_applied %@ %lld %@": {
        "pt-BR": "%1$@ recebeu %2$lld %3$@",
        "en":    "%1$@ received %2$lld %3$@",
        "es":    "%1$@ recibió %2$lld %3$@",
    },
    "duel.event.cards_drawn %@ %lld": {
        "pt-BR": "%1$@ sacou %2$lld carta(s)",
        "en":    "%1$@ drew %2$lld card(s)",
        "es":    "%1$@ robó %2$lld carta(s)",
    },
    "duel.event.card_discarded %@": {
        "pt-BR": "%@ descartou",
        "en":    "%@ discarded",
        "es":    "%@ descartó",
    },
    "duel.event.card_exhausted %@": {
        "pt-BR": "%@ exilou",
        "en":    "%@ exhausted",
        "es":    "%@ exilió",
    },
    "duel.event.deck_shuffled %@": {
        "pt-BR": "%@ embaralhou descarte",
        "en":    "%@ shuffled discard",
        "es":    "%@ barajó descarte",
    },
    "duel.event.fatigue_damage %@ %lld": {
        "pt-BR": "%1$@ tomou %2$lld de fadiga",
        "en":    "%1$@ took %2$lld fatigue",
        "es":    "%1$@ recibió %2$lld de fatiga",
    },
    "duel.event.skip_turn_applied %@": {
        "pt-BR": "%@ foi marcado com skip",
        "en":    "%@ was marked with skip",
        "es":    "%@ fue marcado con salto",
    },
    "duel.event.turn_skipped %@": {
        "pt-BR": "%@ pulou o turno",
        "en":    "%@ skipped turn",
        "es":    "%@ saltó el turno",
    },
    "duel.event.turn_ended %@": {
        "pt-BR": "%@ terminou turno",
        "en":    "%@ ended turn",
        "es":    "%@ terminó turno",
    },
    "duel.event.duel_won %@": {
        "pt-BR": "🏆 %@ venceu",
        "en":    "🏆 %@ won",
        "es":    "🏆 %@ ganó",
    },
    "duel.event.duel_forfeit %@": {
        "pt-BR": "🏳 %@ desistiu",
        "en":    "🏳 %@ forfeited",
        "es":    "🏳 %@ se rindió",
    },

    # ---- STORE ERRORS (aparecem em alerts) ----
    "duel.error.state_not_loaded": {
        "pt-BR": "Estado não carregado",
        "en":    "State not loaded",
        "es":    "Estado no cargado",
    },
    "duel.error.invalid_action %@": {
        "pt-BR": "Ação inválida: %@",
        "en":    "Invalid action: %@",
        "es":    "Acción no válida: %@",
    },
    "duel.error.no_player_id": {
        "pt-BR": "Sem ID do Game Center",
        "en":    "Missing Game Center ID",
        "es":    "Sin ID de Game Center",
    },
    "duel.error.start_failed %@": {
        "pt-BR": "Falha ao iniciar duelo: %@",
        "en":    "Failed to start duel: %@",
        "es":    "Fallo al iniciar duelo: %@",
    },
    "duel.error.no_opponent": {
        "pt-BR": "Sem oponente no match",
        "en":    "No opponent in match",
        "es":    "Sin oponente en la partida",
    },
    "duel.error.state_nil_on_save": {
        "pt-BR": "Estado vazio ao salvar",
        "en":    "Empty state on save",
        "es":    "Estado vacío al guardar",
    },
    "duel.error.end_turn_failed %@": {
        "pt-BR": "Falha ao terminar turno: %@",
        "en":    "Failed to end turn: %@",
        "es":    "Fallo al terminar turno: %@",
    },
}


def main():
    if not XCSTRINGS_PATH.exists():
        print(f"ERRO: {XCSTRINGS_PATH} não encontrado. Rode do diretório do projeto.")
        sys.exit(1)

    with XCSTRINGS_PATH.open("r", encoding="utf-8") as f:
        data = json.load(f)

    if "strings" not in data:
        data["strings"] = {}

    added, updated, skipped = 0, 0, 0

    for key, translations in STRINGS.items():
        existing = data["strings"].get(key)

        if existing is None:
            # Chave nova — cria com todas as línguas
            data["strings"][key] = {
                "extractionState": "manual",
                "localizations": {
                    lang: {
                        "stringUnit": {
                            "state": "translated",
                            "value": val,
                        }
                    }
                    for lang, val in translations.items()
                },
            }
            added += 1
        else:
            # Chave já existe — só adiciona línguas faltando (não sobrescreve)
            localizations = existing.setdefault("localizations", {})
            any_added = False
            for lang, val in translations.items():
                if lang not in localizations:
                    localizations[lang] = {
                        "stringUnit": {
                            "state": "translated",
                            "value": val,
                        }
                    }
                    any_added = True
            if any_added:
                updated += 1
            else:
                skipped += 1

    with XCSTRINGS_PATH.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"✓ Adicionadas: {added}")
    print(f"✓ Atualizadas (línguas faltando): {updated}")
    print(f"✓ Skipped (já completas): {skipped}")
    print(f"✓ Total no arquivo: {len(data['strings'])}")


if __name__ == "__main__":
    main()
