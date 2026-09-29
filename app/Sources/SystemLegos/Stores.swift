import AppKit
import Foundation
import UniformTypeIdentifiers

enum AppFolder {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SystemLegos", isDirectory: true)
    }
}

@MainActor
final class DeckStore: ObservableObject {
    @Published private(set) var deck: Deck = .empty
    @Published private(set) var origin = ""
    @Published private(set) var revision = 0
    @Published var errorMessage: String?

    static var userDeckURL: URL { AppFolder.url.appendingPathComponent("deck.json") }

    init() { load() }

    /// Prefers an imported deck in Application Support, then the copy inside the .app,
    /// then the SwiftPM resource bundle (used by `swift run`).
    func load() {
        var candidates: [(URL, String)] = []
        if FileManager.default.fileExists(atPath: Self.userDeckURL.path) {
            candidates.append((Self.userDeckURL, "Imported deck"))
        }
        if let url = Bundle.main.url(forResource: "deck", withExtension: "json") {
            candidates.append((url, "Built-in deck"))
        } else if let url = Bundle.module.url(forResource: "deck", withExtension: "json") {
            candidates.append((url, "Built-in deck"))
        }
        for (url, name) in candidates {
            do {
                let data = try Data(contentsOf: url)
                deck = try JSONDecoder().decode(Deck.self, from: data)
                origin = name
                revision += 1
                return
            } catch {
                errorMessage = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    func importDeck() {
        let panel = NSOpenPanel()
        panel.title = "Import a deck.json"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            _ = try JSONDecoder().decode(Deck.self, from: data)
            let dest = Self.userDeckURL
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try data.write(to: dest)
            load()
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    func revertToBuiltIn() {
        try? FileManager.default.removeItem(at: Self.userDeckURL)
        load()
    }
}

/// Free-form notes per card (what you built, what broke, what you patched), saved as
/// `notes.json` in Application Support and exportable as a Markdown build journal.
@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [String: String] = [:]
    @Published var errorMessage: String?

    static var fileURL: URL { AppFolder.url.appendingPathComponent("notes.json") }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            notes = decoded
        }
    }

    func save(_ text: String, for id: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { notes.removeValue(forKey: id) } else { notes[id] = trimmed }
        persist()
    }

    func exportJournal(deck: Deck) {
        let panel = NSSavePanel()
        panel.title = "Export build journal"
        panel.nameFieldStringValue = "system-legos-journal.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var out = "# System Legos build journal\n"
        for module in deck.modules {
            let cards = deck.cards.filter { $0.module == module.id && notes[$0.id] != nil }
            guard !cards.isEmpty else { continue }
            out += "\n## \(module.title)\n"
            for card in cards {
                out += "\n### \(card.title)\n\n\(notes[card.id] ?? "")\n"
            }
        }
        do {
            try out.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: AppFolder.url, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(notes).write(to: Self.fileURL)
        } catch {
            errorMessage = "Could not save notes: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var known: Set<String>
    @Published private(set) var review: Set<String>

    private let defaults = UserDefaults.standard

    init() {
        known = Set(defaults.stringArray(forKey: "knownCards") ?? [])
        review = Set(defaults.stringArray(forKey: "reviewCards") ?? [])
    }

    func toggleKnown(_ id: String) {
        if known.remove(id) == nil {
            known.insert(id)
            review.remove(id)
        }
        save()
    }

    func toggleReview(_ id: String) {
        if review.remove(id) == nil {
            review.insert(id)
            known.remove(id)
        }
        save()
    }

    func markKnown(_ id: String) {
        known.insert(id)
        review.remove(id)
        save()
    }

    func markReview(_ id: String) {
        review.insert(id)
        known.remove(id)
        save()
    }

    func reset() {
        known = []
        review = []
        save()
    }

    private func save() {
        defaults.set(Array(known), forKey: "knownCards")
        defaults.set(Array(review), forKey: "reviewCards")
    }
}
