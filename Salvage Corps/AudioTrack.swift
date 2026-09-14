//
//  AudioTrack.swift
//  Salvage Corps
//
//  Constantes de nomes dos arquivos de áudio. Centralizar aqui
//  evita string tipada no código e facilita rename.
//
//  Todos os arquivos são procurados no bundle principal. Formatos
//  aceitos: .mp3, .m4a, .wav, .caf (AudioManager tenta nessa ordem).
//
//  IMPORTANTE: nem todos os arquivos precisam existir. AudioManager
//  faz fallback silencioso pra arquivos ausentes. Isso permite
//  desenvolver a UI antes de ter as tracks finais.
//

import Foundation

enum AudioTrack {

    // MARK: - Music (loops, longos)

    /// Ambient dark drone. 2-4 min, loopable.
    static let musicMenu = "music_menu"

    /// Battle theme. 2-3 min, loopable.
    static let musicCombat = "music_combat"

    // MARK: - SFX (curtos, one-shot)

    /// Ao jogar carta na mão. 0.3-0.6s.
    static let sfxCardPlay = "sfx_card_play"

    /// Ao comprar cartas no começo do turno. 0.4-0.8s.
    static let sfxCardDraw = "sfx_card_draw"

    /// Ao dar dano em inimigo. Impacto físico. 0.3-0.7s.
    static let sfxDamageEnemy = "sfx_damage_enemy"

    /// Ao tomar dano de inimigo. Grunhido/impacto. 0.4-0.8s.
    static let sfxDamagePlayer = "sfx_damage_player"

    /// Ao inimigo morrer. Queda, colapso. 0.6-1.2s.
    static let sfxEnemyDeath = "sfx_enemy_death"

    /// Ao tomar dano moral. Sussurro, whisper, psíquico. 0.5-1.0s.
    static let sfxMoralHit = "sfx_moral_hit"

    /// Ao encerrar turno. Woosh, transição. 0.3-0.6s.
    static let sfxTurnEnd = "sfx_turn_end"

    /// Click de botão genérico. 0.1-0.2s.
    static let sfxClick = "sfx_click"

    /// Stinger de vitória (não loopar). 1-3s.
    static let sfxVictory = "sfx_victory"

    /// Stinger de derrota (não loopar). 1-3s.
    static let sfxDefeat = "sfx_defeat"
}
