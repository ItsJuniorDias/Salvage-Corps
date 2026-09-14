import Foundation

/// Calcula ratings estilo ELO clássico. Estateless, puro, sem side effects —
/// mesmo input SEMPRE dá mesmo output. Fundamental pra que Alice e Bob cheguem
/// no MESMO delta quando processarem o fim do match dos seus lados
/// (sem servidor central).
///
/// **Fórmula ELO clássica**:
/// ```
/// expected = 1 / (1 + 10^((opponentRating - myRating) / 400))
/// delta    = K * (result - expected)
/// newRating = myRating + delta
/// ```
///
/// **K-factor**: quanto maior, mais volátil o rating (subida/queda rápida).
/// K=32 é o padrão FIDE pra jogadores intermediários — bom compromisso pro
/// modo casual PvP.
///
/// **Result**:
/// - `1.0` = venceu
/// - `0.0` = perdeu
/// - `0.5` = empate (não usado hoje mas fica na assinatura pra futuro)
public struct RatingCalculator {

    public static let defaultKFactor: Double = 32.0

    /// Calcula o novo rating do player após um match.
    ///
    /// - Parameters:
    ///   - myRating: rating do player ANTES do match
    ///   - opponentRating: rating do oponente ANTES do match
    ///   - result: 1.0 vitória, 0.0 derrota, 0.5 empate
    ///   - k: K-factor (default 32)
    /// - Returns: novo rating do player, arredondado
    public static func newRating(
        myRating: Int,
        opponentRating: Int,
        result: Double,
        k: Double = defaultKFactor
    ) -> Int {
        let expected = expectedScore(myRating: myRating, opponentRating: opponentRating)
        let deltaRaw = k * (result - expected)
        return Int((Double(myRating) + deltaRaw).rounded())
    }

    /// Delta de rating (novo - antigo). Útil quando o RatingStore precisa
    /// aplicar delta em cima do rating CORRENTE (que pode ter mudado desde que
    /// o match começou) em vez de replace pelo newRating baseado em ratings antigos.
    ///
    /// Ex: você tem 1000, joga match A (grava 1000), joga match B (grava 1000).
    /// A termina, ganha → delta=+16, current vira 1016.
    /// B termina, ganha → delta ainda calculado com base em 1000 vs 1000 = +16,
    /// current vira 1032 (correto: 2 vitórias equivalentes).
    ///
    /// Alternativa incorreta seria replace por newRating(1000, ..., 1.0)=1016 dos
    /// dois, resultando em 1016 final (perdeu 1 vitória).
    public static func delta(
        myRating: Int,
        opponentRating: Int,
        result: Double,
        k: Double = defaultKFactor
    ) -> Int {
        newRating(myRating: myRating, opponentRating: opponentRating,
                  result: result, k: k) - myRating
    }

    /// Probabilidade esperada do player vencer (0.0 a 1.0). Só exposto pra
    /// testes; UI não precisa disso.
    public static func expectedScore(myRating: Int, opponentRating: Int) -> Double {
        let diff = Double(opponentRating - myRating)
        return 1.0 / (1.0 + pow(10.0, diff / 400.0))
    }
}
