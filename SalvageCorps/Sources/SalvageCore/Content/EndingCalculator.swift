import Foundation

/// Calcula qual dos 5 endings o player alcançou baseado nas escolhas
/// terminais dos 3 atos.
///
/// Regras (em ordem de prioridade):
///
/// 1. **Ending SECRETO "O Espelho"** — desbloqueado por condições ocultas
///    (implementadas em sessão futura do meta layer). Placeholder por enquanto.
///
/// 2. **Ending "O Fugitivo"** — quando player escolheu `walkAway` no Ato 3 E
///    o path predominante era Testemunha. É o Testemunha que "não aguentou
///    mais" e desistiu. Ending mais fatalista dos "públicos".
///
/// 3. **Endings puros** (Cúmplice/Contentor/Testemunha) — quando pelo menos
///    2 dos 3 atos foram no mesmo path.
///
/// 4. **Fallback** — se escolhas são todas diferentes (empate 3-way),
///    prevalece a escolha do Ato 3 (última decisão domina).
public enum EndingCalculator {

    /// Retorna o ending final baseado nas consequences acumuladas.
    /// Requer que TODAS as 3 escolhas (act1, act2, act3) tenham sido feitas.
    /// Se qualquer uma for nil, retorna nil.
    ///
    /// - Parameter meta: Estado meta-layer opcional. Se fornecido, checa
    ///   condições do ending secreto "O Espelho". Se nil (default), pula.
    public static func calculate(
        from consequences: ActConsequences,
        meta: MetaLayerConditions? = nil
    ) -> EndingPath? {
        guard let act1 = consequences.act1,
              let act2 = consequences.act2,
              let act3 = consequences.act3 else {
            return nil
        }

        let paths = [act1.endingInfluence, act2.endingInfluence, act3.endingInfluence]

        // 1. Ending SECRETO "O Espelho"
        //    Condições: walkAway + Henry encontrado + 3 ghost cards no deck final
        if let meta = meta,
           act3 == .walkAway,
           meta.didMeetHenry,
           meta.hadAllGhostCards {
            return .espelho
        }

        // 2. "O Fugitivo" — walkAway no Ato 3 + predominância Testemunha
        if act3 == .walkAway {
            let testemunhaCount = paths.filter { $0 == .testemunha }.count
            if testemunhaCount >= 2 {
                return .fugitivo
            }
        }

        // 3. Endings puros — 2+ atos no mesmo path
        let counts = paths.reduce(into: [EndingPath: Int]()) { acc, p in
            acc[p, default: 0] += 1
        }
        if let dominant = counts.first(where: { $0.value >= 2 })?.key {
            return dominant
        }

        // 4. Fallback: prevalece Ato 3 (última escolha)
        return act3.endingInfluence
    }

    /// Retorna string descritiva de como o ending foi calculado. Útil pra debug
    /// e pra mostrar breakdown na tela do ending.
    public static func explanation(for consequences: ActConsequences) -> String {
        guard let ending = calculate(from: consequences) else {
            return "Escolhas incompletas."
        }
        let paths = consequences.allChoices.map { $0.endingInfluence.displayName }
        return "\(paths.joined(separator: " · ")) → \(ending.displayName)"
    }
}

/// Protocolo simples pra abstrair MetaLayerState (que está no app-side,
/// não no core) e permitir o core ler condições sem depender da classe app.
public protocol MetaLayerConditions {
    var didMeetHenry: Bool { get }
    var hadAllGhostCards: Bool { get }
}
