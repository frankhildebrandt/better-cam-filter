import Foundation

enum GestureKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case peace, thumbsUp, openPalm, heartHands, doubleOpenPalm, fingerHeart
    case thumbsDown, doubleThumbsUp, doubleThumbsDown, doublePeace, closedFist, pointingUp

    var id: Self { self }

    var title: String {
        switch self {
        case .peace: "Peace-Zeichen"
        case .thumbsUp: "Daumen hoch"
        case .openPalm: "Offene Hand"
        case .heartHands: "Herz mit beiden Händen"
        case .doubleOpenPalm: "Zwei offene Hände"
        case .fingerHeart: "Fingerherz"
        case .thumbsDown: "Daumen runter"
        case .doubleThumbsUp: "Zweimal Daumen hoch"
        case .doubleThumbsDown: "Zweimal Daumen runter"
        case .doublePeace: "Doppeltes Peace-Zeichen"
        case .closedFist: "Geschlossene Faust"
        case .pointingUp: "Zeigefinger hoch"
        }
    }

    var emoji: String {
        switch self {
        case .peace, .doublePeace: "✌️"
        case .thumbsUp, .doubleThumbsUp: "👍"
        case .openPalm, .doubleOpenPalm: "🖐️"
        case .heartHands: "🫶"
        case .fingerHeart: "🫰"
        case .thumbsDown, .doubleThumbsDown: "👎"
        case .closedFist: "✊"
        case .pointingUp: "☝️"
        }
    }

    var instruction: String {
        switch self {
        case .peace: "Zeige mit einer Hand ein V und halte es kurz."
        case .thumbsUp: "Strecke einen Daumen nach oben und halte die Geste kurz."
        case .openPalm: "Zeige eine offene Hand mit gespreizten Fingern zur Kamera."
        case .heartHands: "Forme mit beiden Händen ein Herz und halte es kurz."
        case .doubleOpenPalm: "Zeige beide offenen Hände zur Kamera."
        case .fingerHeart: "Kreuze Daumen und Zeigefinger zu einem kleinen Fingerherz."
        case .thumbsDown: "Strecke einen Daumen nach unten und halte die Geste kurz."
        case .doubleThumbsUp: "Strecke beide Daumen nach oben."
        case .doubleThumbsDown: "Strecke beide Daumen nach unten."
        case .doublePeace: "Zeige mit beiden Händen ein V."
        case .closedFist: "Zeige eine geschlossene Faust zur Kamera."
        case .pointingUp: "Strecke nur den Zeigefinger nach oben."
        }
    }

    var availableReactions: [ReactionKind] {
        ReactionKind.allCases.filter { $0.compatibleGestures.contains(self) }
    }
}

enum ReactionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case bunnyPeek, goodBean, pawFive, lovePuff, rainbowYay, tinyLove

    var id: Self { self }

    var title: String {
        switch self {
        case .bunnyPeek: "Bunny Peek"
        case .goodBean: "Good Bean"
        case .pawFive: "Paw Five"
        case .lovePuff: "Love Puff"
        case .rainbowYay: "Rainbow Yay"
        case .tinyLove: "Tiny Love"
        }
    }

    var description: String {
        switch self {
        case .bunnyPeek: "Ein kleines Häschen schaut neugierig ins Bild."
        case .goodBean: "Ein fröhlicher kleiner Buddy feiert mit dir."
        case .pawFive: "Eine flauschige Pfote gibt dir ein High Five."
        case .lovePuff: "Ein rosa Herz mit Gesicht lässt kleine Herzchen aufsteigen."
        case .rainbowYay: "Ein pastellfarbener Regenbogen bringt Sternchen mit."
        case .tinyLove: "Ein winziges Herz hüpft über deinen Fingern."
        }
    }

    var duration: Double { 3 }

    var compatibleGestures: Set<GestureKind> {
        switch self {
        case .bunnyPeek: [.peace, .doublePeace]
        case .goodBean: [.thumbsUp, .doubleThumbsUp]
        case .pawFive: [.openPalm, .doubleOpenPalm]
        case .lovePuff: [.heartHands]
        case .rainbowYay: [.doubleOpenPalm, .doubleThumbsUp, .doublePeace]
        case .tinyLove: [.fingerHeart]
        }
    }
}
