import AppKit
import SwiftUI

struct CardView: View {
    let card: Card
    let flipped: Bool
    let isKnown: Bool
    let isReview: Bool
    let heading: String
    let color: Color
    let note: String
    /// Titles of the builds that use this card (bricks only).
    let usedIn: [String]
    let lookup: (String) -> Card?
    let colorOf: (Card) -> Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                status
                front
                if flipped {
                    Divider()
                    answer
                } else {
                    Text(hint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }
            }
            .padding(32)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.top)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
                .fill(color.gradient)
                .frame(height: 6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(flipped ? color.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private var hint: String {
        card.kind == .brick
            ? "Say what it is, when you reach for it, and how it breaks. Then click the card or press Space."
            : "Sketch the assembly: which bricks, in what order, and why. Then click the card or press Space."
    }

    private var status: some View {
        HStack(spacing: 8) {
            StudDot(color: color)
            Text(heading).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Spacer()
            if !note.isEmpty { CardBadge(text: "Notes", color: .purple) }
            if isKnown { CardBadge(text: "Known", color: .green) }
            if isReview { CardBadge(text: "Review", color: .orange) }
        }
    }

    @ViewBuilder
    private var front: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.title)
                .font(.system(size: flipped ? 30 : 38, weight: .bold))
            if let subtitle = card.subtitle {
                Text(subtitle).font(.title3).foregroundStyle(.secondary)
            }
        }
        .textSelection(.enabled)
        if let lego = card.lego {
            HStack(alignment: .top, spacing: 12) {
                BrickLogo(size: 22, color: color)
                VStack(alignment: .leading, spacing: 3) {
                    Text("LEGO VIEW").font(.caption.weight(.bold)).foregroundStyle(color)
                    Text(lego).font(.system(size: 16)).italic()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .textSelection(.enabled)
        }
        if card.kind == .build {
            Block(title: "The problem", color: color) {
                Text(card.summary).font(.system(size: 17))
            }
        }
    }

    @ViewBuilder
    private var answer: some View {
        VStack(alignment: .leading, spacing: 20) {
            if card.kind == .brick {
                Block(title: "What it is", color: color) {
                    Text(card.summary).font(.system(size: 16))
                }
            }
            if let steps = card.steps, !steps.isEmpty {
                Block(title: card.kind == .build ? "The assembly" : "Steps", color: color) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.callout.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(color.gradient, in: Circle())
                                Text(step).font(.system(size: 15))
                            }
                        }
                    }
                }
            }
            if let uses = card.uses, !uses.isEmpty {
                Block(title: "Bricks snapped together", color: color) {
                    FlowLayout(spacing: 8) {
                        ForEach(uses, id: \.self) { id in
                            BrickChip(id: id, card: lookup(id), color: lookup(id).map(colorOf) ?? .gray)
                        }
                    }
                }
            }
            ForEach(card.sections, id: \.title) { section in
                Block(title: section.title, color: color) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(section.items, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•").foregroundStyle(color)
                                Text(item).font(.system(size: 15))
                            }
                        }
                    }
                }
            }
            if !usedIn.isEmpty {
                Block(title: "Snapped into these builds", color: color) {
                    Text(usedIn.joined(separator: " · ")).font(.callout).foregroundStyle(.secondary)
                }
            }
            if !card.links.isEmpty {
                Block(title: "Read in depth", color: color) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(card.links) { ReadingRow(reading: $0) }
                    }
                }
            }
            if !note.isEmpty {
                Block(title: "My notes", color: .purple) {
                    Text(note).font(.system(size: 15))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .textSelection(.enabled)
    }
}

private struct Block<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReadingRow: View {
    let reading: Reading

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: reading.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                if let url = URL(string: reading.url) {
                    // A focusable Link makes the card's ScrollView jump down to it on appear.
                    Button(reading.title) { NSWorkspace.shared.open(url) }
                        .buttonStyle(.link)
                        .focusable(false)
                        .font(.system(size: 15, weight: .medium))
                        .help(reading.url)
                } else {
                    Text(reading.title)
                }
                Text([reading.kind.capitalized, reading.host, reading.note].compactMap { $0 }
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A referenced brick; click it to peek at what that brick is without leaving the build.
private struct BrickChip: View {
    let id: String
    let card: Card?
    let color: Color
    @StateObject private var popover = PopoverState()

    var body: some View {
        Button { popover.isShown.toggle() } label: {
            HStack(spacing: 5) {
                StudDot(color: color)
                Text(card?.title ?? id).font(.callout.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.13), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $popover.isShown, arrowEdge: .bottom) {
            if let card {
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.title).font(.headline)
                    if let lego = card.lego { Text(lego).italic().foregroundStyle(.secondary) }
                    Text(card.summary)
                }
                .padding(16)
                .frame(width: 380)
                .textSelection(.enabled)
            }
        }
    }
}

@MainActor
private final class PopoverState: ObservableObject {
    @Published var isShown = false
}

struct CardBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

/// Lays children out left to right, wrapping onto new rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += row + spacing
                row = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            row = max(row, size.height)
        }
        return CGSize(width: widest, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += row + spacing
                row = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}
