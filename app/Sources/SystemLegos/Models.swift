import Foundation
import SwiftUI

struct Deck: Codable {
    var modules: [Module]
    var cards: [Card]

    static let empty = Deck(modules: [], cards: [])
}

/// A course module (sidebar source) such as "The Bricks", split into groups such as "Compute".
struct Module: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let groups: [ModuleGroup]
}

struct ModuleGroup: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let color: String?
}

enum CardKind: String, Codable, CaseIterable, Identifiable {
    case brick, build

    var id: String { rawValue }
    var title: String { self == .brick ? "Bricks" : "Builds" }
}

/// A brick is a concept card (a component, rule, paper or tool). A build is an assembly:
/// a problem whose answer is an ordered list of steps and the bricks it snaps together.
struct Card: Codable, Identifiable, Hashable {
    let id: String
    let kind: CardKind
    let module: String
    let group: String
    let title: String
    let subtitle: String?
    let lego: String?
    let summary: String
    let steps: [String]?
    let uses: [String]?
    let sections: [CardSection]
    let links: [Reading]

    var key: String { GroupKey.make(module, group) }
}

struct CardSection: Codable, Hashable {
    let title: String
    let items: [String]
}

struct Reading: Codable, Hashable, Identifiable {
    let title: String
    let url: String
    /// `paper`, `blog`, `docs`, `book`, `talk`, `tool` or `course`.
    let kind: String
    let note: String?

    var id: String { url }

    var symbol: String {
        switch kind {
        case "paper": "doc.text"
        case "blog": "text.bubble"
        case "docs": "book.closed"
        case "book": "books.vertical"
        case "talk": "play.rectangle"
        case "tool": "hammer"
        case "course": "graduationcap"
        default: "link"
        }
    }

    var host: String {
        URL(string: url)?.host()?.replacingOccurrences(of: "www.", with: "") ?? ""
    }
}

/// A `(module, group)` pair such as `bricks|compute`, used for sidebar selection.
enum GroupKey {
    static func make(_ module: String, _ group: String) -> String { "\(module)|\(group)" }
}

enum BrickColor {
    static func named(_ name: String?) -> Color {
        switch name {
        case "red": .red
        case "orange": .orange
        case "yellow": Color(red: 0.85, green: 0.65, blue: 0.0)
        case "green": .green
        case "teal": .teal
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        case "brown": .brown
        default: .gray
        }
    }
}
