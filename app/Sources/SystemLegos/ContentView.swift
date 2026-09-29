import SwiftUI

enum PracticeMode: String, CaseIterable, Identifiable {
    case all, notKnown, review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All cards"
        case .notKnown: "Not yet known"
        case .review: "Review only"
        }
    }
}

enum StudyMode: String, CaseIterable, Identifiable {
    case learn, test

    var id: String { rawValue }
    var title: String { self == .learn ? "Learn" : "Test" }
}

struct ContentView: View {
    @EnvironmentObject private var store: DeckStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var notes: NotesStore
    @EnvironmentObject private var printRequest: PrintRequest

    /// Newline-separated `module|group` keys; `*` means every group in the deck.
    @AppStorage("selectedGroups") private var selectedRaw = "*"
    @AppStorage("shuffle") private var shuffle = false
    @AppStorage("practiceMode") private var modeRaw = PracticeMode.all.rawValue
    @AppStorage("cardKind") private var kindRaw = CardKind.brick.rawValue
    @AppStorage("studyMode") private var studyRaw = StudyMode.learn.rawValue

    @StateObject private var session = StudySession()
    @StateObject private var draft = NoteDraft()

    private var cards: [Card] { store.deck.cards }
    private var selectedKind: CardKind { CardKind(rawValue: kindRaw) ?? .brick }
    private var kind: CardKind { session.kind }
    private var mode: PracticeMode { PracticeMode(rawValue: modeRaw) ?? .all }
    private var order: [Int] { session.order }
    private var position: Int { session.position }
    private var study: StudyMode { StudyMode(rawValue: studyRaw) ?? .learn }
    /// In Learn mode every card is shown in full; in Test mode the answer is hidden until revealed.
    private var flipped: Bool { study == .learn || session.flipped }

    private var allGroupKeys: Set<String> {
        Set(store.deck.modules.flatMap { m in m.groups.map { GroupKey.make(m.id, $0.id) } })
    }

    private var selected: Binding<Set<String>> {
        Binding(
            get: {
                selectedRaw == "*" ? allGroupKeys : Set(selectedRaw.split(separator: "\n").map(String.init))
            },
            set: { selectedRaw = $0.sorted().joined(separator: "\n") })
    }

    private var currentIndex: Int? {
        guard order.indices.contains(position), order.allSatisfy({ $0 < cards.count }) else { return nil }
        return order[position]
    }

    private var cardsByID: [String: Card] {
        Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func group(of card: Card) -> (Module, ModuleGroup)? {
        guard let module = store.deck.modules.first(where: { $0.id == card.module }),
              let group = module.groups.first(where: { $0.id == card.group }) else { return nil }
        return (module, group)
    }

    private func color(of card: Card) -> Color { BrickColor.named(group(of: card)?.1.color) }

    private func heading(of card: Card) -> String {
        guard let (module, group) = group(of: card) else { return card.module }
        return "\(module.title) — \(group.label)"
    }

    /// Titles of the builds that snap this card in.
    private func usedIn(_ card: Card) -> [String] {
        cards.filter { $0.uses?.contains(card.id) == true }.map(\.title)
    }

    private var selectedCards: [Card] {
        cards.filter { selected.wrappedValue.contains($0.key) }
    }

    var body: some View {
        NavigationSplitView {
            FilterView(
                deck: store.deck,
                selected: selected,
                collapsed: $session.collapsedModules,
                kind: kind,
                cardCount: order.count,
                cardNoun: kind == .brick ? "brick cards" : "build cards")
            .navigationSplitViewColumnWidth(min: 260, ideal: 310)
        } detail: {
            detail
                .padding(24)
                .toolbar { toolbar }
        }
        .onAppear(perform: rebuild)
        .onChange(of: selectedRaw) { rebuild() }
        .onChange(of: shuffle) { rebuild() }
        .onChange(of: modeRaw) { rebuild() }
        .onChange(of: kindRaw) { rebuild() }
        .onChange(of: studyRaw) { rebuild() }
        .onChange(of: store.revision) { rebuild() }
        .sheet(isPresented: editingNote) { notesSheet }
        .sheet(isPresented: $printRequest.isPresented) { printSheet }
        .alert("Something went wrong", isPresented: showingError) {
            Button("OK") { clearErrors() }
        } message: {
            Text(store.errorMessage ?? notes.errorMessage ?? "")
        }
    }

    private var editingNote: Binding<Bool> {
        Binding(
            get: { session.editingNote != nil },
            set: { if !$0 { session.editingNote = nil } })
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil || notes.errorMessage != nil },
            set: { if !$0 { clearErrors() } })
    }

    private func clearErrors() {
        store.errorMessage = nil
        notes.errorMessage = nil
    }

    @ViewBuilder
    private var notesSheet: some View {
        if let index = session.editingNote {
            let id = cards[index].id
            NotesEditorView(
                card: cards[index],
                draft: draft,
                onSave: {
                    notes.save(draft.text, for: id)
                    session.editingNote = nil
                },
                onCancel: { session.editingNote = nil })
        }
    }

    private var printSheet: some View {
        let lookup = cardsByID
        let headingFor: (Card) -> String = { heading(of: $0) }
        let titleFor: (String) -> String = { lookup[$0]?.title ?? $0 }
        return PrintGuideView(
            cards: selectedCards,
            reviewIDs: progress.review,
            notes: notes.notes,
            heading: headingFor,
            brickTitle: titleFor,
            onClose: { printRequest.isPresented = false })
    }

    @ViewBuilder
    private var detail: some View {
        if study == .test && session.finished {
            testSummary
        } else if let index = currentIndex {
            let card = cards[index]
            let lookup = cardsByID
            VStack(spacing: 18) {
                header
                CardView(
                    card: card,
                    flipped: flipped,
                    isKnown: progress.known.contains(card.id),
                    isReview: progress.review.contains(card.id),
                    heading: heading(of: card),
                    color: color(of: card),
                    note: notes.notes[card.id] ?? "",
                    usedIn: usedIn(card),
                    lookup: { lookup[$0] },
                    colorOf: color(of:))
                .id(card.id)
                .onTapGesture { if study == .test { session.flipped = true } }
                .animation(.easeInOut(duration: 0.15), value: flipped)
                controls(index: index, id: card.id)
                    .disabled(session.editingNote != nil)
            }
        } else {
            ContentUnavailableView(
                "No cards to practice",
                systemImage: "square.stack.3d.up.slash",
                description: Text(emptyHint))
        }
    }

    private var emptyHint: String {
        switch mode {
        case .review: "No cards are marked for review in the selected groups. Press R on a card to mark it."
        case .notKnown: "Every card in the selected groups is marked known."
        case .all: "Tick at least one group in the sidebar, or switch between Bricks and Builds."
        }
    }

    private var header: some View {
        HStack {
            Text("Card \(position + 1) of \(order.count)")
                .font(.headline)
            Spacer()
            if study == .test {
                let answered = session.answers.count
                let correct = session.answers.values.filter { $0 }.count
                Text("Score \(correct) of \(answered) · \(order.count - answered) to go")
                    .font(.callout.weight(.medium))
            } else {
                let ids = Set(order.map { cards[$0].id })
                Text("Known \(ids.intersection(progress.known).count) · Review \(ids.intersection(progress.review).count)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var testSummary: some View {
        let correct = session.answers.values.filter { $0 }.count
        let missed = order.filter { session.answers[cards[$0].id] == false }
        let percent = order.isEmpty ? 0 : Int((Double(correct) / Double(order.count) * 100).rounded())
        VStack(spacing: 16) {
            Image(systemName: missed.isEmpty ? "star.circle.fill" : "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(missed.isEmpty ? .yellow : .green)
            Text("Test complete").font(.largeTitle.weight(.semibold))
            Text("\(correct) of \(order.count) correct (\(percent)%)").font(.title2)
            Text(missed.isEmpty
                 ? "Every card is now marked known."
                 : "Cards you got are marked known; the \(missed.count) you missed are marked for review.")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if !missed.isEmpty {
                    Button("Retest the \(missed.count) missed") { retest(missed) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
                Button("Start a new test") { rebuild() }
                Button("Switch to Learn") { studyRaw = StudyMode.learn.rawValue }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controls(index: Int, id: String) -> some View {
        HStack(spacing: 12) {
            Button { move(-1) } label: { Label("Previous", systemImage: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: [])
            if study == .test {
                if flipped {
                    Button { answer(id, correct: false) } label: { Label("Missed it (M)", systemImage: "xmark.circle") }
                        .keyboardShortcut("m", modifiers: [])
                        .tint(.orange)
                    Button { answer(id, correct: true) } label: { Label("Got it (G)", systemImage: "checkmark.circle") }
                        .keyboardShortcut("g", modifiers: [])
                        .tint(.green)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button { session.flipped = true } label: {
                        Label(kind == .brick ? "Show answer" : "Show assembly", systemImage: "eye")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    .buttonStyle(.borderedProminent)
                }
            }
            Button { move(1) } label: {
                Label(study == .test ? "Skip" : "Next", systemImage: "chevron.right")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            Spacer()
            Button {
                draft.text = notes.notes[id] ?? ""
                session.editingNote = index
            } label: { Label("Notes (N)", systemImage: notes.notes[id] == nil ? "square.and.pencil" : "note.text") }
            .keyboardShortcut("n", modifiers: [])
            if study == .learn {
                Button { progress.toggleKnown(id) } label: {
                    Label("Known (K)", systemImage: progress.known.contains(id) ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .keyboardShortcut("k", modifiers: [])
                Button { progress.toggleReview(id) } label: {
                    Label("Review (R)", systemImage: progress.review.contains(id) ? "flag.fill" : "flag")
                }
                .keyboardShortcut("r", modifiers: [])
            }
        }
        .controlSize(.large)
    }

    /// Records the answer, updates known/review, and moves to the next unanswered card.
    private func answer(_ id: String, correct: Bool) {
        session.answers[id] = correct
        if correct { progress.markKnown(id) } else { progress.markReview(id) }
        let next = (1...order.count).map { (position + $0) % order.count }
            .first { session.answers[cards[order[$0]].id] == nil }
        if let next {
            session.position = next
            session.flipped = false
        } else {
            session.finished = true
        }
    }

    private func retest(_ indices: [Int]) {
        session.order = shuffle ? indices.shuffled() : indices
        session.position = 0
        session.flipped = false
        session.answers = [:]
        session.finished = false
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("Cards", selection: $kindRaw) {
                ForEach(CardKind.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .help("Bricks: single concepts. Builds: assemble bricks to solve a problem.")
        }
        ToolbarItem(placement: .navigation) {
            Picker("Mode", selection: $studyRaw) {
                ForEach(StudyMode.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .help("Learn: see each card in full. Test: recall it, then mark whether you got it.")
        }
        ToolbarItemGroup {
            Picker("Practice", selection: $modeRaw) {
                ForEach(PracticeMode.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            Toggle(isOn: $shuffle) { Label("Shuffle", systemImage: "shuffle") }
                .help("Shuffle the cards")
            Button { rebuild() } label: { Label("Restart", systemImage: "arrow.counterclockwise") }
                .help("Start again from the first card")
            Button { printRequest.isPresented = true } label: { Label("Print", systemImage: "printer") }
                .help("Print the selected cards as a study guide or save them as a PDF")
        }
    }

    private func move(_ delta: Int) {
        guard !order.isEmpty else { return }
        session.position = (position + delta + order.count) % order.count
        session.flipped = false
    }

    private func rebuild() {
        let chosen = selected.wrappedValue
        session.kind = selectedKind
        var picked = cards.indices.filter { cards[$0].kind == selectedKind && chosen.contains(cards[$0].key) }
        switch mode {
        case .all: break
        case .notKnown: picked.removeAll { progress.known.contains(cards[$0].id) }
        case .review: picked.removeAll { !progress.review.contains(cards[$0].id) }
        }
        session.order = shuffle ? picked.shuffled() : picked
        session.position = 0
        session.flipped = false
        session.answers = [:]
        session.finished = false
    }
}

@MainActor
final class StudySession: ObservableObject {
    @Published var order: [Int] = []
    @Published var kind: CardKind = .brick
    @Published var position = 0
    @Published var flipped = false
    @Published var collapsedModules: Set<String> = []
    @Published var editingNote: Int?
    /// Test mode: card id → whether it was recalled correctly in this run.
    @Published var answers: [String: Bool] = [:]
    @Published var finished = false
}

/// The text being edited in the notes sheet.
@MainActor
final class NoteDraft: ObservableObject {
    @Published var text = ""
}
