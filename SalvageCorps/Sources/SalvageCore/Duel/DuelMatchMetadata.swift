import Foundation

/// Metadata do match — informações auxiliares que não fazem parte do estado
/// do JOGO mas ficam junto pra que ambos os players tenham acesso.
///
/// **Ratings congelados no início**: Alice grava `hostRatingAtStart` quando cria
/// o match. Bob grava `opponentRatingAtStart` quando abre e submete deck. Ao
/// fim do duelo, cada player usa esses valores CONGELADOS pra calcular delta
/// (via `RatingCalculator`) — garante que ambos chegam no mesmo número sem
/// precisar de servidor central pra confirmar.
///
/// **Backward compat**: `DuelState.matchMetadata` é Optional. States antigos
/// (Fase 8) sem metadata continuam decodificando normal — só não têm rating
/// (tratados como "unranked, ignorar rating no fim").
public struct DuelMatchMetadata: Codable, Equatable {

    /// Se `false`, o fim do duelo não altera rating de ninguém.
    /// Reservado pra futuro (Fase 10+ pode ter matches amigáveis).
    /// Fase 9 MVP: sempre `true` pra matches novos.
    public var isRanked: Bool

    /// ID do player que criou o match (host, playerA no state). Setado no
    /// `DuelFactory.createHostedDuel` via `DuelMatchStore`. Serve pra que
    /// clients possam responder "eu sou host ou oponente?" sem precisar
    /// carregar o `DuelState` inteiro — importante pra rows da lista de
    /// matches, onde metadata é cacheado mas state completo não.
    ///
    /// Vazio ("") em states migrados de versões anteriores — nesse caso,
    /// clients caem em fallback (não mostrar tier do oponente).
    public var hostID: String

    /// Rating do host no momento da criação do match. Congelado.
    public var hostRatingAtStart: Int

    /// Rating do opponent no momento em que ele submeteu deck.
    /// Zero até esse momento — `RatingStore` valida.
    public var opponentRatingAtStart: Int

    public init(
        isRanked: Bool = true,
        hostID: String,
        hostRatingAtStart: Int,
        opponentRatingAtStart: Int = 0
    ) {
        self.isRanked = isRanked
        self.hostID = hostID
        self.hostRatingAtStart = hostRatingAtStart
        self.opponentRatingAtStart = opponentRatingAtStart
    }

    /// Rating do player identificado por `playerID`, dado que `hostID` é o host
    /// do match (playerA no DuelState). Se o playerID não bater com nenhum
    /// dos dois, retorna nil.
    public func ratingAtStart(for playerID: String, hostID: String, opponentID: String) -> Int? {
        if playerID == hostID { return hostRatingAtStart }
        if playerID == opponentID { return opponentRatingAtStart }
        return nil
    }

    /// Retorna o rating congelado do OPONENTE de `myPlayerID` — usa o `hostID`
    /// gravado no próprio metadata pra desambiguar sem precisar do state completo.
    /// Retorna nil se ainda não foi setado (`opponentRatingAtStart` = 0 antes do
    /// oponente abrir o match).
    public func opponentRating(for myPlayerID: String) -> Int? {
        // Metadata legacy sem hostID — não dá pra determinar
        guard !hostID.isEmpty else { return nil }
        let oppRating: Int
        if myPlayerID == hostID {
            oppRating = opponentRatingAtStart
        } else {
            oppRating = hostRatingAtStart
        }
        return oppRating > 0 ? oppRating : nil
    }
}
