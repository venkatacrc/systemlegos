import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct SystemLegosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DeckStore()
    @StateObject private var progress = ProgressStore()
    @StateObject private var notes = NotesStore()
    @StateObject private var printRequest = PrintRequest()

    var body: some Scene {
        WindowGroup("System Legos") {
            ContentView()
                .environmentObject(store)
                .environmentObject(progress)
                .environmentObject(notes)
                .environmentObject(printRequest)
                .frame(minWidth: 1000, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .printItem) {
                Button("Print Study Guide / Save as PDF…") { printRequest.isPresented = true }
                    .keyboardShortcut("p")
            }
            CommandGroup(after: .newItem) {
                Button("Import Deck…") { store.importDeck() }
                    .keyboardShortcut("o")
                Button("Reload Deck") { store.load() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Use Built-in Deck") { store.revertToBuiltIn() }
                Divider()
                Button("Export Build Journal…") { notes.exportJournal(deck: store.deck) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(notes.notes.isEmpty)
                Divider()
                Button("Reset Progress…") { progress.reset() }
            }
        }
    }
}
