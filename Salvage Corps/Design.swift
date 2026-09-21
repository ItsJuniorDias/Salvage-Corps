//
//  Design.swift
//  Salvage Corps
//
//  Sistema de design centralizado. Muda aqui, muda no jogo inteiro.
//

import SwiftUI

/// Escala global da UI. O layout foi desenhado pra um iPhone em landscape
/// (852×393 pt); no Mac a janela é bem maior, então tudo — fontes, cartas,
/// espaçamentos — é multiplicado por `factor`. No iPhone o fator fica em 1.
///
/// É `@Observable`: qualquer `body` que lê `factor` (via `.s` ou
/// `SalvageFont`) re-renderiza quando a janela muda de tamanho.
@Observable
final class UIScale {
    static let shared = UIScale()

    /// Tamanho de referência do design original (iPhone landscape).
    static let designSize = CGSize(width: 852, height: 393)

    private(set) var factor: CGFloat = 1

    /// Tamanho atual da janela, pra layouts que precisam saber o espaço real.
    private(set) var windowSize: CGSize = designSize

    private init() {}

    func update(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        windowSize = size
        #if targetEnvironment(macCatalyst)
        let raw = min(size.width / Self.designSize.width,
                      size.height / Self.designSize.height)
        let newFactor = (min(max(raw, 1), 2.6) * 20).rounded() / 20
        #else
        let newFactor: CGFloat = 1
        #endif
        if newFactor != factor { factor = newFactor }
    }
}

extension Int {
    /// Valor em pontos escalado pela janela (`UIScale`).
    var s: CGFloat { CGFloat(self) * UIScale.shared.factor }
}

extension Double {
    /// Valor em pontos escalado pela janela (`UIScale`).
    var s: CGFloat { CGFloat(self) * UIScale.shared.factor }
}

extension CGFloat {
    /// Valor em pontos escalado pela janela (`UIScale`).
    var s: CGFloat { self * UIScale.shared.factor }
}

/// Tipografia do jogo.
///
/// Combinação temática:
/// - **New York** (serif Apple nativa, via `design: .serif` — não existe
///   por nome PostScript, `.custom("NewYork-…")` caía na fonte padrão): títulos, headers, números — feel
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
        .system(size: size.s, weight: .bold, design: .serif)
    }

    /// Título de seção (nome de encontro, VITÓRIA/DERROTA)
    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size.s, weight: .semibold, design: .serif)
    }

    /// Header pequeno (nome de carta, nome de inimigo)
    static func header(_ size: CGFloat = 13) -> Font {
        .system(size: size.s, weight: .semibold, design: .serif)
    }

    /// Números importantes (HP, custos, dano) — monospaced digit
    static func number(_ size: CGFloat = 13) -> Font {
        .system(size: size.s, weight: .bold, design: .serif)
            .monospacedDigit()
    }

    // MARK: - Typewriter (American Typewriter) — corpo e flavor

    /// Corpo geral (subtítulo, descrição de encontro, efeito de carta)
    static func body(_ size: CGFloat = 12) -> Font {
        .custom("AmericanTypewriter", size: size.s, relativeTo: .body)
    }

    /// Corpo bold (labels de recurso "HP:", "MORAL:")
    static func bodyBold(_ size: CGFloat = 11) -> Font {
        .custom("AmericanTypewriter-Bold", size: size.s, relativeTo: .body)
    }

    /// Flavor text (quote do menu, flavor de carta, diálogos)
    /// Italic feita via .italic() no Text porque AmericanTypewriter não tem italic PostScript
    static func flavor(_ size: CGFloat = 12) -> Font {
        .custom("AmericanTypewriter-Light", size: size.s, relativeTo: .caption)
    }

    /// Uppercase label pequeno (categoria, tipo, tracking)
    static func label(_ size: CGFloat = 10) -> Font {
        .custom("AmericanTypewriter-Bold", size: size.s, relativeTo: .caption)
    }

    /// Legendinha (contadores de pilha, texto secundário)
    static func caption(_ size: CGFloat = 10) -> Font {
        .custom("AmericanTypewriter", size: size.s, relativeTo: .caption2)
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
