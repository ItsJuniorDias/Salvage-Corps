import XCTest
@testable import SalvageCore

final class AchievementEvaluatorTests: XCTestCase {

    // Helper que produz snapshot com defaults sensatos
    private func snapshot(
        iWon: Bool = true,
        myRatingAfter: Int = 1016,
        opponentRatingAtStart: Int = 1000,
        myRatingAtStart: Int = 1000,
        iTookNoDamage: Bool = false,
        totalWinsAfter: Int = 1,
        totalMatchesAfter: Int = 1,
        currentStreakAfter: Int = 1
    ) -> DuelOutcomeSnapshot {
        DuelOutcomeSnapshot(
            iWon: iWon,
            myRatingAfter: myRatingAfter,
            opponentRatingAtStart: opponentRatingAtStart,
            myRatingAtStart: myRatingAtStart,
            iTookNoDamage: iTookNoDamage,
            totalWinsAfter: totalWinsAfter,
            totalMatchesAfter: totalMatchesAfter,
            currentStreakAfter: currentStreakAfter
        )
    }

    private func identifiers(_ results: [(Achievement, Double)]) -> Set<String> {
        Set(results.map { $0.0.identifier })
    }

    private func percent(for ach: Achievement, in results: [(Achievement, Double)]) -> Double? {
        results.first { $0.0 == ach }?.1
    }

    // MARK: - Tier progression

    func test_tierSargento_triggersAt1200() {
        let s = snapshot(myRatingAfter: 1200)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertTrue(ids.contains(Achievement.tierSargento.identifier))
        XCTAssertFalse(ids.contains(Achievement.tierTenente.identifier))
    }

    func test_tierOficial_alsoIncludesLowerTiers() {
        // Reportar todos os tiers atingidos garante que se o app tá desatualizado
        // e o rating pulou vários tiers, o Game Center marca todos.
        let s = snapshot(myRatingAfter: 1900)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertTrue(ids.contains(Achievement.tierSargento.identifier))
        XCTAssertTrue(ids.contains(Achievement.tierTenente.identifier))
        XCTAssertTrue(ids.contains(Achievement.tierCapitao.identifier))
        XCTAssertTrue(ids.contains(Achievement.tierOficial.identifier))
    }

    func test_belowSargento_reportsNoTier() {
        let s = snapshot(myRatingAfter: 1199)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertFalse(ids.contains(Achievement.tierSargento.identifier))
    }

    // MARK: - Wins

    func test_firstWin_triggersWins1() {
        let s = snapshot(iWon: true, totalWinsAfter: 1)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertTrue(ids.contains(Achievement.wins1.identifier))
    }

    func test_loss_doesNotTriggerWinAchievements() {
        let s = snapshot(iWon: false, totalWinsAfter: 5)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertFalse(ids.contains(Achievement.wins1.identifier))
        XCTAssertFalse(ids.contains(Achievement.wins10.identifier))
    }

    func test_wins10_reportsProgressWhenIntermediary() {
        let s = snapshot(iWon: true, totalWinsAfter: 5)
        let pct = percent(for: .wins10, in: AchievementEvaluator.evaluate(s))
        XCTAssertNotNil(pct)
        XCTAssertEqual(pct!, 0.5, accuracy: 0.001)
    }

    func test_wins10_reports100PercentAtTarget() {
        let s = snapshot(iWon: true, totalWinsAfter: 10)
        let pct = percent(for: .wins10, in: AchievementEvaluator.evaluate(s))
        XCTAssertEqual(pct!, 1.0, accuracy: 0.001)
    }

    func test_wins10_capsAt100PercentEvenAbove() {
        let s = snapshot(iWon: true, totalWinsAfter: 999)
        let pct = percent(for: .wins10, in: AchievementEvaluator.evaluate(s))
        XCTAssertEqual(pct!, 1.0, accuracy: 0.001)
    }

    // MARK: - Match participation

    func test_matches10_reportsProgressEvenOnLoss() {
        // Participação conta INDEPENDENTE de vencer — reporta em vitória E derrota
        let s = snapshot(iWon: false, totalMatchesAfter: 3)
        let pct = percent(for: .matches10, in: AchievementEvaluator.evaluate(s))
        XCTAssertNotNil(pct)
        XCTAssertEqual(pct!, 0.3, accuracy: 0.001)
    }

    // MARK: - Streaks

    func test_streak3_triggersAt3Wins() {
        let s = snapshot(iWon: true, currentStreakAfter: 3)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertTrue(ids.contains(Achievement.streak3.identifier))
        XCTAssertFalse(ids.contains(Achievement.streak5.identifier))
    }

    func test_streak5_alsoTriggersStreak3() {
        // 5 vitórias inclui as 3 primeiras — reportar ambos
        let s = snapshot(iWon: true, currentStreakAfter: 5)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertTrue(ids.contains(Achievement.streak3.identifier))
        XCTAssertTrue(ids.contains(Achievement.streak5.identifier))
    }

    func test_lossWithStreak_doesNotTrigger() {
        // Derrota nunca é reportada em achievements de vitória
        let s = snapshot(iWon: false, currentStreakAfter: 0)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertFalse(ids.contains(Achievement.streak3.identifier))
    }

    // MARK: - Perfect duel

    func test_perfectDuel_triggersOnWinWithNoDamage() {
        let s = snapshot(iWon: true, iTookNoDamage: true)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertTrue(ids.contains(Achievement.perfectDuel.identifier))
    }

    func test_perfectDuel_notTriggeredOnLossEvenWithoutDamage() {
        // Cenário improvável (perder sem tomar dano?) mas cover regra: só em vitória
        let s = snapshot(iWon: false, iTookNoDamage: true)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertFalse(ids.contains(Achievement.perfectDuel.identifier))
    }

    func test_perfectDuel_notTriggeredIfTookDamage() {
        let s = snapshot(iWon: true, iTookNoDamage: false)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertFalse(ids.contains(Achievement.perfectDuel.identifier))
    }

    // MARK: - Underdog

    func test_underdog_triggersAt200PointDifference() {
        let s = snapshot(
            iWon: true,
            opponentRatingAtStart: 1200,
            myRatingAtStart: 1000
        )
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertTrue(ids.contains(Achievement.underdog.identifier))
    }

    func test_underdog_notTriggeredAt199Difference() {
        let s = snapshot(
            iWon: true,
            opponentRatingAtStart: 1199,
            myRatingAtStart: 1000
        )
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertFalse(ids.contains(Achievement.underdog.identifier))
    }

    func test_underdog_notTriggeredWhenOpponentRatingUnknown() {
        // Se metadata era legacy (opponentRatingAtStart=0), não pode determinar
        let s = snapshot(iWon: true, opponentRatingAtStart: 0)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertFalse(ids.contains(Achievement.underdog.identifier))
    }

    func test_underdog_notTriggeredWhenFavorite() {
        let s = snapshot(iWon: true, opponentRatingAtStart: 800, myRatingAtStart: 1200)
        let ids = identifiers(AchievementEvaluator.evaluate(s))
        XCTAssertFalse(ids.contains(Achievement.underdog.identifier))
    }
}
