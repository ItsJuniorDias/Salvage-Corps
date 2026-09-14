import XCTest
@testable import SalvageCore

final class RatingCalculatorTests: XCTestCase {

    // MARK: - Cenários canônicos

    func test_expectedScore_equalRatings_isHalf() {
        let e = RatingCalculator.expectedScore(myRating: 1000, opponentRating: 1000)
        XCTAssertEqual(e, 0.5, accuracy: 0.001)
    }

    func test_expectedScore_stronger_isGreaterThanHalf() {
        let e = RatingCalculator.expectedScore(myRating: 1400, opponentRating: 1000)
        XCTAssertGreaterThan(e, 0.5)
        // ELO clássico: diff 400 = ~91% expected
        XCTAssertEqual(e, 0.909, accuracy: 0.01)
    }

    func test_expectedScore_weaker_isLessThanHalf() {
        let e = RatingCalculator.expectedScore(myRating: 1000, opponentRating: 1400)
        XCTAssertLessThan(e, 0.5)
        XCTAssertEqual(e, 0.091, accuracy: 0.01)
    }

    // MARK: - Vitórias / derrotas equal rating

    func test_winAgainstEqual_gainsHalfK() {
        // K=32, expected=0.5, result=1.0 → delta = 32*(1-0.5) = 16
        let new = RatingCalculator.newRating(myRating: 1000, opponentRating: 1000, result: 1.0)
        XCTAssertEqual(new, 1016)
    }

    func test_lossAgainstEqual_losesHalfK() {
        let new = RatingCalculator.newRating(myRating: 1000, opponentRating: 1000, result: 0.0)
        XCTAssertEqual(new, 984)
    }

    func test_drawAgainstEqual_isNoChange() {
        let new = RatingCalculator.newRating(myRating: 1000, opponentRating: 1000, result: 0.5)
        XCTAssertEqual(new, 1000)
    }

    // MARK: - Underdog vs favorite

    func test_winAsUnderdog_gainsMore() {
        // 800 vs 1200, ganha → grande recompensa
        let delta = RatingCalculator.delta(myRating: 800, opponentRating: 1200, result: 1.0)
        XCTAssertGreaterThan(delta, 16, "Underdog ganhando deve levar mais que match-parelho")
        XCTAssertLessThanOrEqual(delta, 32, "Limite máximo é K")
    }

    func test_winAsFavorite_gainsLess() {
        let delta = RatingCalculator.delta(myRating: 1200, opponentRating: 800, result: 1.0)
        XCTAssertLessThan(delta, 16, "Favorito ganhando deve levar menos que match-parelho")
        XCTAssertGreaterThan(delta, 0, "Ainda deve ser positivo")
    }

    func test_lossAsFavorite_losesMore() {
        let delta = RatingCalculator.delta(myRating: 1200, opponentRating: 800, result: 0.0)
        XCTAssertLessThan(delta, -16, "Favorito perdendo deve perder mais")
    }

    func test_lossAsUnderdog_losesLess() {
        let delta = RatingCalculator.delta(myRating: 800, opponentRating: 1200, result: 0.0)
        XCTAssertGreaterThan(delta, -16, "Underdog perdendo perde menos")
        XCTAssertLessThan(delta, 0, "Ainda deve ser negativo")
    }

    // MARK: - Simetria (fundamental pra consistência sem servidor)

    func test_symmetry_winnerGainsExactlyLoserLoses() {
        // Se A ganha X pontos, B perde EXATAMENTE X.
        // Isso preserva "energia total" do sistema — importante pra ELO honesto.
        for (rA, rB) in [(1000, 1000), (1200, 800), (900, 1500), (1600, 1400)] {
            let gainA = RatingCalculator.delta(myRating: rA, opponentRating: rB, result: 1.0)
            let lossB = RatingCalculator.delta(myRating: rB, opponentRating: rA, result: 0.0)
            XCTAssertEqual(gainA, -lossB,
                "Simetria quebrada em (\(rA), \(rB)): A ganha \(gainA), B perde \(lossB)")
        }
    }

    // MARK: - K-factor customizado

    func test_smallerK_producesSmallerDeltas() {
        let deltaK32 = RatingCalculator.delta(myRating: 1000, opponentRating: 1000, result: 1.0, k: 32)
        let deltaK16 = RatingCalculator.delta(myRating: 1000, opponentRating: 1000, result: 1.0, k: 16)
        XCTAssertEqual(deltaK32, 16)
        XCTAssertEqual(deltaK16, 8)
    }

    // MARK: - Edge cases

    func test_extremeRatingDifference_deltaConverges() {
        // Diff enorme: favorito quase certo → delta ≈ 0 pra favorito, ≈ K pro underdog
        let favoriteGain = RatingCalculator.delta(myRating: 2000, opponentRating: 500, result: 1.0)
        XCTAssertEqual(favoriteGain, 0, "Favorito extremo ganhando: ~0 delta")

        let underdogGain = RatingCalculator.delta(myRating: 500, opponentRating: 2000, result: 1.0)
        XCTAssertEqual(underdogGain, 32, "Underdog extremo ganhando: quase K completo")
    }

    func test_lowRating_stillProducesValidResult() {
        // Ratings baixos não quebram
        let new = RatingCalculator.newRating(myRating: 100, opponentRating: 100, result: 1.0)
        XCTAssertEqual(new, 116)
    }
}
