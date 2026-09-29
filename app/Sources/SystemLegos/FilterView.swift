import SwiftUI

struct FilterView: View {
    let deck: Deck
    @Binding var selected: Set<String>
    @Binding var collapsed: Set<String>
    let kind: CardKind
    let cardCount: Int
    let cardNoun: String

    var body: some View {
        List {
            HStack(spacing: 10) {
                BrickLogo(size: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("System Legos").font(.title3.weight(.semibold))
                    Text("Snap-together system design").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
            .selectionDisabled()

            Section("Practice these") {
                ForEach(deck.modules) { module in
                    DisclosureGroup(isExpanded: Binding(
                        get: { !collapsed.contains(module.id) },
                        set: { open in
                            if open { collapsed.remove(module.id) } else { collapsed.insert(module.id) }
                        })
                    ) {
                        HStack {
                            Button("Select all") { setAll(module, on: true) }
                            Button("Clear") { setAll(module, on: false) }
                        }
                        .buttonStyle(.link)
                        .font(.caption)

                        ForEach(module.groups) { group in
                            Toggle(isOn: binding(for: GroupKey.make(module.id, group.id))) {
                                HStack(spacing: 6) {
                                    StudDot(color: BrickColor.named(group.color))
                                    Text(group.label)
                                    Spacer()
                                    Text("\(count(module, group))")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    } label: {
                        Text(module.title).font(.headline)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Text("\(cardCount) \(cardNoun) selected")
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(.bar)
        }
    }

    private func count(_ module: Module, _ group: ModuleGroup) -> Int {
        deck.cards.filter { $0.kind == kind && $0.module == module.id && $0.group == group.id }.count
    }

    private func binding(for key: String) -> Binding<Bool> {
        Binding(
            get: { selected.contains(key) },
            set: { on in
                if on { selected.insert(key) } else { selected.remove(key) }
            })
    }

    private func setAll(_ module: Module, on: Bool) {
        for group in module.groups {
            let key = GroupKey.make(module.id, group.id)
            if on { selected.insert(key) } else { selected.remove(key) }
        }
    }
}

struct StudDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color.gradient)
            .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
            .frame(width: 10, height: 10)
    }
}

/// A top-down 2×2 LEGO brick, used as the sidebar logo.
struct BrickLogo: View {
    let size: CGFloat
    var color: Color = Color(red: 0.86, green: 0.12, blue: 0.12)

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.18)
            .fill(color.gradient)
            .overlay {
                Grid(horizontalSpacing: size * 0.12, verticalSpacing: size * 0.12) {
                    ForEach(0..<2, id: \.self) { _ in
                        GridRow {
                            ForEach(0..<2, id: \.self) { _ in
                                Circle()
                                    .fill(color.gradient)
                                    .brightness(0.08)
                                    .shadow(color: .black.opacity(0.35), radius: size * 0.02, y: size * 0.03)
                                    .frame(width: size * 0.3, height: size * 0.3)
                            }
                        }
                    }
                }
            }
            .frame(width: size, height: size)
    }
}
