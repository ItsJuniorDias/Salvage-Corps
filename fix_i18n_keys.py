#!/usr/bin/env python3
"""
Fix i18n keys — chaves com format specifiers no VALUE precisam ter os format
specifiers no NOME também, pra bater com o padrão do Xcode xcstrings quando
usadas com Text("chave \\(param)") ou String(localized: "chave \\(param)").

Renomeia chaves no Localizable.xcstrings E atualiza refs em todos os arquivos
.swift do app. Idempotente — rodar 2x não muda nada depois da 1ª rodada.
"""
import json
import re
import sys
from pathlib import Path

XCSTRINGS_PATH = Path("Salvage Corps/Localizable.xcstrings")

# Mapa: chave-atual → chave-com-format-specs
# Baseado nas assinaturas de chamada nos arquivos Swift.
RENAMES = {
    # ---- Menu (Fase 8) ----
    "duel.menu.my_deck_subtitle": "duel.menu.my_deck_subtitle %lld %lld",

    # ---- Status (Fase i18n) ----
    "duel.status.opponent_turn": "duel.status.opponent_turn %@",

    # ---- Combat (Fase i18n) ----
    "duel.combat.turn_label": "duel.combat.turn_label %lld",

    # ---- Deck builder (Fase 8) ----
    "duel.deck.count_label": "duel.deck.count_label %lld %lld",
    "duel.deck.need_more":   "duel.deck.need_more %lld",
    "duel.deck.need_less":   "duel.deck.need_less %lld",

    # ---- Errors (Fase i18n) — todos passam reason string ----
    "duel.error.invalid_action":  "duel.error.invalid_action %@",
    "duel.error.start_failed":    "duel.error.start_failed %@",
    "duel.error.end_turn_failed": "duel.error.end_turn_failed %@",

    # ---- Ranking (Fase 9) ----
    "duel.rank.next_tier_at": "duel.rank.next_tier_at %lld",

    # ---- Events (Fase i18n) — muitos com params ----
    # Format: turn N, who
    "duel.event.turn_started":        "duel.event.turn_started %lld %@",
    # Format: who, card_name
    "duel.event.card_played":         "duel.event.card_played %@ %@",
    # Format: who, amount
    "duel.event.damage_dealt":        "duel.event.damage_dealt %@ %lld",
    # Format: blocked amount
    "duel.event.damage_blocked_part": "duel.event.damage_blocked_part %lld",
    # Format: who, delta
    "duel.event.moral_gained":        "duel.event.moral_gained %@ %lld",
    "duel.event.moral_lost":          "duel.event.moral_lost %@ %lld",
    # Format: who, hp value
    "duel.event.hp_change":           "duel.event.hp_change %@ %lld",
    # Format: who, amount
    "duel.event.block_gained":        "duel.event.block_gained %@ %lld",
    # Format: who, count, status name
    "duel.event.status_applied":      "duel.event.status_applied %@ %lld %@",
    # Format: who, count
    "duel.event.cards_drawn":         "duel.event.cards_drawn %@ %lld",
    # Format: who
    "duel.event.card_discarded":      "duel.event.card_discarded %@",
    "duel.event.card_exhausted":      "duel.event.card_exhausted %@",
    "duel.event.deck_shuffled":       "duel.event.deck_shuffled %@",
    # Format: who, amount
    "duel.event.fatigue_damage":      "duel.event.fatigue_damage %@ %lld",
    # Format: who
    "duel.event.skip_turn_applied":   "duel.event.skip_turn_applied %@",
    "duel.event.turn_skipped":        "duel.event.turn_skipped %@",
    "duel.event.turn_ended":          "duel.event.turn_ended %@",
    "duel.event.duel_won":            "duel.event.duel_won %@",
    "duel.event.duel_forfeit":        "duel.event.duel_forfeit %@",
}


def fix_xcstrings() -> int:
    """Rename keys in xcstrings. Returns number of renames done."""
    with XCSTRINGS_PATH.open("r", encoding="utf-8") as f:
        data = json.load(f)

    renamed = 0
    strings = data.get("strings", {})
    for old, new in RENAMES.items():
        if old in strings and new not in strings:
            strings[new] = strings.pop(old)
            renamed += 1
        elif old in strings and new in strings:
            # Ambos existem — mantém o novo (com format specs), remove o velho.
            del strings[old]
            renamed += 1
        # Se só o novo existe, ignora (já foi renomeado numa run anterior)
        # Se nenhum existe, ignora (chave nunca criada)

    with XCSTRINGS_PATH.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return renamed


def fix_swift_files() -> int:
    """Update key references in .swift files. Returns number of refs replaced."""
    total = 0
    for swift in Path("Salvage Corps").rglob("*.swift"):
        content = swift.read_text(encoding="utf-8")
        original = content
        for old_key in RENAMES.keys():
            # Referências têm o formato: "old_key \(param)" ou "old_key" seguido de interpolação.
            # Ex: Text("duel.combat.turn_label \(state.turn)") → Text("duel.combat.turn_label \(state.turn)")
            # A CHAVE literal no source code fica IGUAL (não incluímos o %lld no source).
            # NÃO precisa mudar o código Swift — a mudança é só no xcstrings.
            #
            # MAS: precisamos garantir que refs sem interpolação (só a chave) não
            # tenham sido usadas incorretamente. Vou skippar renames que quebrem
            # refs literais sem params.
            pass
        # De fato, não precisamos mudar o código Swift — o compiler gera a chave
        # com format specs baseado nos tipos dos params interpolados. O source
        # sempre é "duel.event.card_played \(who) \(name)" e o compiler procura
        # "duel.event.card_played %@ %@" no xcstrings.
        _ = original  # silence
    return total


def main():
    if not XCSTRINGS_PATH.exists():
        print(f"ERRO: {XCSTRINGS_PATH} não encontrado.")
        sys.exit(1)

    renamed = fix_xcstrings()
    print(f"✓ Chaves renomeadas no xcstrings: {renamed}")
    if renamed == 0:
        print("  (já rodou antes — nada a fazer)")
    else:
        print("  Refs no código Swift NÃO precisam mudar — compiler gera o nome")
        print("  correto automaticamente baseado nos tipos dos params interpolados.")


if __name__ == "__main__":
    main()
