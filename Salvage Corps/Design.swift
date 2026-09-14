//
//  Design.swift
//  Salvage Corps
//
//  Sistema de design centralizado. Muda aqui, muda no jogo inteiro.
//

import SwiftUI

/// Tipografia do jogo.
///
/// Combinação temática:
/// - **New York** (serif Apple nativa): títulos, headers, números — feel
///   histórico refinado, como livro antigo ou documento oficial
/// - **American Typewriter**: corpo, cartas, flavor — feel de diário de
///   campo, telegrama, memorando militar
///
/// Ambas nativas iOS 17+, sem download de fontes. Se o dispositivo do
/// jogador não tiver alguma (raro), Swift faz fallback pra system default.
enum SalvageFont {

    // MARK: - Serif (New York) — títulos e destaques

    /// Título gigante (tela de menu, fim de combate)
    static func titleXL(_ size: CGFloat = 44) -> Font {
        .custom("NewYork-Bold", size: size, relativeTo: .largeTitle)
    }

    /// Título de seção (nome de encontro, VITÓRIA/DERROTA)
    static func title(_ size: CGFloat = 22) -> Font {
        .custom("NewYork-Semibold", size: size, relativeTo: .title2)
    }

    /// Header pequeno (nome de carta, nome de inimigo)
    static func header(_ size: CGFloat = 13) -> Font {
        .custom("NewYork-Semibold", size: size, relativeTo: .headline)
    }

    /// Números importantes (HP, custos, dano) — monospaced digit
    static func number(_ size: CGFloat = 13) -> Font {
        .custom("NewYork-Bold", size: size, relativeTo: .body)
            .monospacedDigit()
    }

    // MARK: - Typewriter (American Typewriter) — corpo e flavor

    /// Corpo geral (subtítulo, descrição de encontro, efeito de carta)
    static func body(_ size: CGFloat = 12) -> Font {
        .custom("AmericanTypewriter", size: size, relativeTo: .body)
    }

    /// Corpo bold (labels de recurso "HP:", "MORAL:")
    static func bodyBold(_ size: CGFloat = 11) -> Font {
        .custom("AmericanTypewriter-Bold", size: size, relativeTo: .body)
    }

    /// Flavor text (quote do menu, flavor de carta, diálogos)
    /// Italic feita via .italic() no Text porque AmericanTypewriter não tem italic PostScript
    static func flavor(_ size: CGFloat = 12) -> Font {
        .custom("AmericanTypewriter-Light", size: size, relativeTo: .caption)
    }

    /// Uppercase label pequeno (categoria, tipo, tracking)
    static func label(_ size: CGFloat = 10) -> Font {
        .custom("AmericanTypewriter-Bold", size: size, relativeTo: .caption)
    }

    /// Legendinha (contadores de pilha, texto secundário)
    static func caption(_ size: CGFloat = 10) -> Font {
        .custom("AmericanTypewriter", size: size, relativeTo: .caption2)
            .monospacedDigit()
    }
}

/// Paleta de cores do jogo.
enum SalvageColor {
    static let hpRed = Color(red: 0.75, green: 0.15, blue: 0.15)
    static let moralPurple = Color(red: 0.55, green: 0.35, blue: 0.65)
    static let blockBlue = Color(red: 0.35, green: 0.55, blue: 0.85)
    static let energyOrange = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let bloodAccent = Color(red: 0.55, green: 0.12, blue: 0.12)
    static let boneWhite = Color(red: 0.92, green: 0.88, blue: 0.78)
    static let mudBrown = Color(red: 0.35, green: 0.28, blue: 0.18)
    static let gasGreen = Color(red: 0.55, green: 0.55, blue: 0.25)
    /// Dourado desbotado — usado como marca visual de cicatrizes em cartas.
    static let scarGold = Color(red: 0.82, green: 0.68, blue: 0.35)
}
