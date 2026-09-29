import SwiftUI

struct NotesEditorView: View {
    let card: Card
    @ObservedObject var draft: NoteDraft
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notes — \(card.title)").font(.title2.weight(.semibold))
            Text(card.kind == .build
                 ? "Record what you built, what you broke, what happened, and how you patched it."
                 : "Put it in your own words: a mnemonic, a gotcha, a number worth remembering, a link you liked.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextEditor(text: $draft.text)
                .font(.system(size: 14))
                .frame(minHeight: 260)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.3)))
            HStack {
                Text("Clear the text and save to delete the note.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave() }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 620)
    }
}
