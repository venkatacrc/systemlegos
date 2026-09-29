import AppKit
import SwiftUI

@MainActor
final class PrintRequest: ObservableObject {
    @Published var isPresented = false
}

struct PrintOptions {
    var sections = true
    var links = true
    var notes = true
}

/// Lays the selected cards out as a study guide and sends them to the print system, which
/// paginates them and either shows the Print dialog or saves a PDF.
@MainActor
enum CardPrinter {
    static func run(cards: [Card], notes: [String: String], heading: (Card) -> String,
                    brickTitle: (String) -> String, title: String, options: PrintOptions, saveTo url: URL?) {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.topMargin = 48
        info.bottomMargin = 48
        info.leftMargin = 54
        info.rightMargin = 54
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isVerticallyCentered = false
        info.isHorizontallyCentered = false
        info.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter.rawValue] = true
        if let url {
            info.jobDisposition = .save
            info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL.rawValue] = url
        }

        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let view = PrintTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
        view.jobTitle = title
        view.isEditable = false
        view.isVerticallyResizable = true
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textStorage?.setAttributedString(document(
            cards: cards, notes: notes, heading: heading, brickTitle: brickTitle, title: title, options: options))
        if let layout = view.layoutManager, let container = view.textContainer {
            layout.ensureLayout(for: container)
            view.setFrameSize(NSSize(width: width, height: ceil(layout.usedRect(for: container).height)))
        }

        let op = NSPrintOperation(view: view, printInfo: info)
        op.jobTitle = title
        op.showsPrintPanel = url == nil
        op.showsProgressPanel = true
        op.run()
    }

    static func document(cards: [Card], notes: [String: String], heading: (Card) -> String,
                         brickTitle: (String) -> String, title: String, options: PrintOptions) -> NSAttributedString {
        let doc = NSMutableAttributedString()
        let ink = NSColor.black
        let accent = NSColor(red: 0.72, green: 0.10, blue: 0.10, alpha: 1)
        let muted = NSColor(white: 0.35, alpha: 1)

        func add(_ text: String, _ font: NSFont, _ color: NSColor = ink,
                 before: CGFloat = 0, after: CGFloat = 2, indent: CGFloat = 0, link: String? = nil) {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = before
            style.paragraphSpacing = after
            style.lineHeightMultiple = 1.1
            style.firstLineHeadIndent = indent
            style.headIndent = indent
            var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
            if let link, let url = URL(string: link) { attrs[.link] = url }
            doc.append(NSAttributedString(string: text + "\n", attributes: attrs))
        }
        func label(_ text: String) {
            add(text.uppercased(), .systemFont(ofSize: 8.5, weight: .bold), accent, before: 6, after: 1)
        }
        let body = NSFont.systemFont(ofSize: 10.5)
        let italic = NSFontManager.shared.convert(body, toHaveTrait: .italicFontMask)

        add(title, .systemFont(ofSize: 20, weight: .bold), ink, after: 4)
        add("\(cards.count) card\(cards.count == 1 ? "" : "s")", .systemFont(ofSize: 10), muted, after: 10)

        var lastHeading = ""
        for card in cards {
            let h = heading(card)
            if h != lastHeading {
                add(h, .systemFont(ofSize: 14, weight: .bold), accent, before: 18, after: 4)
                lastHeading = h
            }
            add(card.title, .systemFont(ofSize: 12.5, weight: .semibold), ink, before: 12, after: 1)
            if let subtitle = card.subtitle { add(subtitle, .systemFont(ofSize: 10), muted) }
            if let lego = card.lego { add("LEGO view: \(lego)", italic, muted) }
            label(card.kind == .build ? "The problem" : "What it is")
            add(card.summary, body)
            if let steps = card.steps, !steps.isEmpty {
                label(card.kind == .build ? "The assembly" : "Steps")
                for (i, step) in steps.enumerated() { add("\(i + 1). \(step)", body, indent: 8) }
            }
            if let uses = card.uses, !uses.isEmpty {
                label("Bricks")
                add(uses.map(brickTitle).joined(separator: " · "), body)
            }
            if options.sections {
                for section in card.sections {
                    label(section.title)
                    for item in section.items { add("• \(item)", body, indent: 8) }
                }
            }
            if options.links && !card.links.isEmpty {
                label("Read in depth")
                for r in card.links {
                    add("\(r.title) — \(r.url)", .systemFont(ofSize: 9.5), muted, indent: 8, link: r.url)
                }
            }
            if options.notes, let note = notes[card.id] {
                label("My notes")
                add(note, body)
            }
        }
        return doc
    }
}

private final class PrintTextView: NSTextView {
    var jobTitle = "System Legos"
    override var printJobTitle: String { jobTitle }
}

struct PrintGuideView: View {
    /// The cards in the sidebar selection, in deck order.
    let cards: [Card]
    let reviewIDs: Set<String>
    let notes: [String: String]
    let heading: (Card) -> String
    let brickTitle: (String) -> String
    let onClose: () -> Void

    @AppStorage("printBricks") private var bricks = true
    @AppStorage("printBuilds") private var builds = true
    @AppStorage("printSections") private var sections = true
    @AppStorage("printLinks") private var links = true
    @AppStorage("printNotes") private var includeNotes = true
    @AppStorage("printReviewOnly") private var reviewOnly = false

    private let title = "System Legos — Study Guide"

    private var picked: [Card] {
        cards.filter { card in
            (card.kind == .brick ? bricks : builds) && (!reviewOnly || reviewIDs.contains(card.id))
        }
    }

    private var options: PrintOptions {
        PrintOptions(sections: sections, links: links, notes: includeNotes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Print study guide").font(.title2.weight(.semibold))
            Text("Prints the cards in the groups ticked in the sidebar.")
                .font(.callout).foregroundStyle(.secondary)

            GroupBox("Cards") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Bricks (concepts)", isOn: $bricks)
                    Toggle("Builds (assemblies, projects and drills)", isOn: $builds)
                    Toggle("Only cards marked for review", isOn: $reviewOnly)
                    Text("\(picked.count) card\(picked.count == 1 ? "" : "s") will be printed")
                        .font(.callout.weight(.medium))
                }
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            GroupBox("Include") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Details (when to use, trade-offs, failure modes, drills)", isOn: $sections)
                    Toggle("Reading links", isOn: $links)
                    Toggle("My notes", isOn: $includeNotes)
                }
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onClose() }
                    .keyboardShortcut(.cancelAction)
                Button("Save as PDF…") { savePDF() }
                Button("Print…") { print() }
                    .keyboardShortcut(.defaultAction)
            }
            .disabled(picked.isEmpty)
        }
        .padding(24)
        .frame(width: 560)
    }

    private func print() {
        let (cards, options) = (picked, options)
        onClose()
        DispatchQueue.main.async {
            CardPrinter.run(cards: cards, notes: notes, heading: heading, brickTitle: brickTitle,
                            title: title, options: options, saveTo: nil)
        }
    }

    private func savePDF() {
        let panel = NSSavePanel()
        panel.title = "Save study guide as PDF"
        panel.nameFieldStringValue = "\(title).pdf"
        panel.allowedContentTypes = [.pdf]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let (cards, options) = (picked, options)
        onClose()
        DispatchQueue.main.async {
            CardPrinter.run(cards: cards, notes: notes, heading: heading, brickTitle: brickTitle,
                            title: title, options: options, saveTo: url)
        }
    }
}
