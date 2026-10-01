'use strict';

const $ = (sel) => document.querySelector(sel);

function h(tag, attrs = {}, ...children) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
        if (v == null || v === false) continue;
        if (k === 'class') el.className = v;
        else if (k === 'style' && typeof v === 'object') {
            for (const [p, val] of Object.entries(v)) p.startsWith('--') ? el.style.setProperty(p, val) : (el.style[p] = val);
        }
        else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
        else if (typeof v === 'boolean') el[k] = v;
        else el.setAttribute(k, v);
    }
    for (const c of children.flat(Infinity)) {
        if (c == null || c === false) continue;
        el.append(c instanceof Node ? c : String(c));
    }
    return el;
}

// ---- Saved state (localStorage) ----

const saved = {
    get(key, fallback) {
        try {
            const v = localStorage.getItem('systemLegos.' + key);
            return v == null ? fallback : JSON.parse(v);
        } catch {
            return fallback;
        }
    },
    set(key, value) {
        localStorage.setItem('systemLegos.' + key, JSON.stringify(value));
    },
};

const prefs = {
    selected: saved.get('selected', '*'),
    kind: saved.get('kind', 'brick'),
    study: saved.get('study', 'learn'),
    practice: saved.get('practice', 'all'),
    shuffle: saved.get('shuffle', false),
    collapsed: saved.get('collapsed', []),
    print: saved.get('print', { bricks: true, builds: true, details: true, links: true, notes: true, reviewOnly: false }),
};

function setPref(key, value) {
    prefs[key] = value;
    saved.set(key, value);
}

const progress = {
    known: new Set(saved.get('known', [])),
    review: new Set(saved.get('review', [])),
    save() {
        saved.set('known', [...this.known]);
        saved.set('review', [...this.review]);
    },
    markKnown(id) { this.known.add(id); this.review.delete(id); this.save(); },
    markReview(id) { this.review.add(id); this.known.delete(id); this.save(); },
    toggleKnown(id) { this.known.has(id) ? this.known.delete(id) : this.markKnown(id); this.save(); },
    toggleReview(id) { this.review.has(id) ? this.review.delete(id) : this.markReview(id); this.save(); },
};

/** Card id → note text, the same shape as the Mac app's notes.json. */
let notes = saved.get('notes', {});

let deck = null;
let loadError = null;
/** Card id → card, group key → {module, group}, card id → titles of builds using it. */
let byId = {}, groupsByKey = {}, usedIn = {};

const session = { order: [], position: 0, flipped: false, answers: {}, finished: false };

// ---- Deck helpers ----

const groupKey = (module, group) => `${module}|${group}`;

const COLORS = {
    red: '#e5383b', orange: '#f08c00', yellow: '#e6b400', green: '#2f9e44', teal: '#0c9aa6',
    blue: '#1c7ed6', indigo: '#5c5fd6', purple: '#9c4fd6', pink: '#e64980', brown: '#a0703c',
};
const colorNamed = (name) => COLORS[name] ?? '#868e96';
const colorOf = (card) => colorNamed(groupsByKey[groupKey(card.module, card.group)]?.group.color);

const NOUNS = { brick: 'bricks', build: 'builds' };
const KIND_ICONS = { paper: '📄', blog: '📝', docs: '📘', book: '📚', talk: '🎤', tool: '🛠', course: '🎓' };

function indexDeck() {
    byId = Object.fromEntries(deck.cards.map((c) => [c.id, c]));
    groupsByKey = {};
    for (const m of deck.modules) for (const g of m.groups) groupsByKey[groupKey(m.id, g.id)] = { module: m, group: g };
    usedIn = {};
    for (const c of deck.cards) for (const u of c.uses ?? []) (usedIn[u] ??= []).push(c.title);
}

function allGroupKeys() {
    return deck.modules.flatMap((m) => m.groups.map((g) => groupKey(m.id, g.id)));
}

function selectedSet() {
    return new Set(prefs.selected === '*' ? allGroupKeys() : prefs.selected);
}

function setSelected(set) {
    const all = allGroupKeys();
    setPref('selected', all.every((k) => set.has(k)) ? '*' : [...set].sort());
}

function currentCard() {
    const id = session.order[session.position];
    return id != null ? byId[id] ?? null : null;
}

function shuffled(list) {
    const a = [...list];
    for (let i = a.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
}

function host(url) {
    try { return new URL(url).hostname.replace(/^www\./, ''); } catch { return ''; }
}

// ---- Session ----

function rebuild() {
    const selected = selectedSet();
    let picked = deck.cards
        .filter((c) => c.kind === prefs.kind && selected.has(groupKey(c.module, c.group)))
        .map((c) => c.id);
    if (prefs.practice === 'notKnown') picked = picked.filter((id) => !progress.known.has(id));
    if (prefs.practice === 'review') picked = picked.filter((id) => progress.review.has(id));
    startSession(prefs.shuffle ? shuffled(picked) : picked);
}

function startSession(order) {
    Object.assign(session, { order, position: 0, flipped: false, answers: {}, finished: false });
    render();
}

function move(delta) {
    const n = session.order.length;
    if (!n) return;
    session.position = (session.position + delta + n) % n;
    session.flipped = false;
    render();
}

function reveal() {
    if (prefs.study !== 'test' || session.flipped) return;
    session.flipped = true;
    render();
}

function answer(correct) {
    const card = currentCard();
    if (!card || !session.flipped) return;
    session.answers[card.id] = correct;
    correct ? progress.markKnown(card.id) : progress.markReview(card.id);
    const n = session.order.length;
    for (let step = 1; step <= n; step++) {
        const p = (session.position + step) % n;
        if (!(session.order[p] in session.answers)) {
            session.position = p;
            session.flipped = false;
            render();
            return;
        }
    }
    session.finished = true;
    render();
}

// ---- Rendering ----

function render() {
    renderSwitches();
    renderStatus();
    renderStage();
    renderActions();
    if ($('#drawer').classList.contains('open')) renderDrawer();
}

function renderSwitches() {
    for (const [id, value] of [['#kind-switch', prefs.kind], ['#study-switch', prefs.study]]) {
        for (const b of $(id).querySelectorAll('button')) b.classList.toggle('on', b.dataset.value === value);
    }
}

function renderStatus() {
    const el = $('#status');
    el.replaceChildren();
    if (!deck || !session.order.length || (prefs.study === 'test' && session.finished)) return;
    const n = session.order.length;
    el.append(h('span', {}, h('strong', {}, `Card ${session.position + 1}`), ` of ${n}`));
    if (prefs.study === 'test') {
        const answered = Object.keys(session.answers).length;
        const correct = Object.values(session.answers).filter(Boolean).length;
        el.append(h('span', {}, `Score ${correct} of ${answered} · ${n - answered} to go`));
    } else {
        const known = session.order.filter((id) => progress.known.has(id)).length;
        const review = session.order.filter((id) => progress.review.has(id)).length;
        el.append(h('span', {}, `Known ${known} · Review ${review}`));
    }
}

function renderStage() {
    const stage = $('#stage');
    const prevCard = stage.querySelector('.card');
    const keepScroll = prevCard && prevCard.dataset.id === String(session.order[session.position]) ? prevCard.scrollTop : 0;
    stage.replaceChildren();
    if (loadError) {
        stage.append(h('div', { class: 'empty' }, h('h2', {}, 'Could not load the cards'), h('p', {}, loadError)));
        return;
    }
    if (!deck) {
        stage.append(h('div', { class: 'empty' }, 'Loading cards…'));
        return;
    }
    if (prefs.study === 'test' && session.finished) {
        stage.append(testSummary());
        return;
    }
    const card = currentCard();
    if (!card) {
        stage.append(h('div', { class: 'empty' },
            h('div', { class: 'big' }, '🧱'),
            h('h2', {}, 'No cards to practice'),
            h('p', {}, emptyHint()),
            h('button', { class: 'btn primary', style: { flex: 'none', padding: '10px 24px' }, onclick: openDrawer }, 'Choose modules')));
        return;
    }
    const el = cardView(card, prefs.study === 'learn' || session.flipped);
    el.addEventListener('click', (e) => { if (!e.target.closest('button, a')) reveal(); });
    addSwipe(el);
    stage.append(el);
    el.scrollTop = keepScroll;
}

function emptyHint() {
    if (prefs.practice === 'review') return `No ${NOUNS[prefs.kind]} are marked for review in the selected groups.`;
    if (prefs.practice === 'notKnown') return `Every ${prefs.kind} in the selected groups is marked known.`;
    return `Tick at least one group that has ${NOUNS[prefs.kind]}.`;
}

function block(title, ...content) {
    return h('section', { class: 'block' }, h('h3', {}, title), content);
}

function chip(id) {
    const target = byId[id];
    return h('button', {
        class: 'chip',
        style: { '--dot': target ? colorOf(target) : '#868e96' },
        onclick: () => target && openPeek(target),
    }, h('span', { class: 'stud' }), target?.title ?? id);
}

function cardView(card, flipped) {
    const color = colorOf(card);
    const info = groupsByKey[groupKey(card.module, card.group)];
    const note = notes[card.id] ?? '';
    const isBuild = card.kind === 'build';
    const el = h('article', {
        class: 'card' + (flipped ? ' flipped' : ''),
        style: { '--accent': color },
        'data-id': card.id,
    },
        h('div', { class: 'badges' },
            h('span', { class: 'label' }, h('span', { class: 'stud' }), h('span', {}, info?.group.label ?? card.group)),
            note && h('span', { class: 'badge notes' }, 'Notes'),
            progress.known.has(card.id) && h('span', { class: 'badge known' }, 'Known'),
            progress.review.has(card.id) && h('span', { class: 'badge review' }, 'Review'),
            h('button', { class: 'note-btn', onclick: () => openNotes(card), title: 'Notes (N)' }, '✎ Notes')),
        h('h1', {}, card.title),
        card.subtitle && h('p', { class: 'subtitle' }, card.subtitle),
        card.lego && h('div', { class: 'lego-view' },
            h('span', { class: 'logo', 'aria-hidden': 'true' }),
            h('div', {}, h('div', { class: 'block', style: { marginTop: 0 } }, h('h3', {}, 'LEGO view')), h('p', {}, card.lego))),
        isBuild && block('The problem', h('p', {}, card.summary)));

    if (!flipped) {
        el.append(h('div', { class: 'hint' }, isBuild
            ? 'Sketch the assembly: which bricks, in what order, and why. Then tap the card.'
            : 'Say what it is, when you reach for it, and how it breaks. Then tap the card.'));
        return el;
    }

    if (!isBuild) el.append(block('What it is', h('p', {}, card.summary)));
    if (card.steps?.length) {
        el.append(block(isBuild ? 'The assembly' : 'Steps', h('ol', {}, card.steps.map((s) => h('li', {}, s)))));
    }
    if (card.uses?.length) el.append(block('Bricks snapped together', h('div', { class: 'chips' }, card.uses.map(chip))));
    for (const s of card.sections) el.append(block(s.title, h('ul', {}, s.items.map((i) => h('li', {}, i)))));
    const builds = usedIn[card.id];
    if (builds?.length) el.append(block('Snapped into these builds', h('p', { class: 'muted' }, builds.join(' · '))));
    if (card.links.length) {
        el.append(block('Read in depth', card.links.map((r) => h('div', { class: 'reading' },
            h('span', { class: 'kind', title: r.kind }, KIND_ICONS[r.kind] ?? '🔗'),
            h('div', {},
                h('a', { href: r.url, target: '_blank', rel: 'noopener' }, r.title),
                h('div', { class: 'meta' }, [r.kind[0].toUpperCase() + r.kind.slice(1), host(r.url), r.note].filter(Boolean).join(' · ')))))));
    }
    if (note) {
        const b = block('My notes', h('div', { class: 'my-notes' }, note));
        b.classList.add('notes');
        el.append(b);
    }
    return el;
}

function testSummary() {
    const correct = Object.values(session.answers).filter(Boolean).length;
    const missed = session.order.filter((id) => session.answers[id] === false);
    const total = session.order.length;
    const percent = total ? Math.round((correct / total) * 100) : 0;
    return h('div', { class: 'summary' },
        h('div', { class: 'big' }, missed.length ? '🧱' : '🏆'),
        h('h2', {}, 'Test complete'),
        h('div', { class: 'score' }, `${correct} of ${total} correct (${percent}%)`),
        h('p', {}, missed.length
            ? `Cards you got are marked known; the ${missed.length} you missed are marked for review.`
            : 'Every card is now marked known.'),
        h('div', { class: 'buttons' },
            missed.length > 0 && h('button', {
                class: 'btn primary',
                onclick: () => startSession(prefs.shuffle ? shuffled(missed) : missed),
            }, `Retest the ${missed.length} missed`),
            h('button', { class: 'btn', onclick: rebuild }, 'Start a new test'),
            h('button', { class: 'btn', onclick: () => { setPref('study', 'learn'); rebuild(); } }, 'Switch to Learn')));
}

function renderActions() {
    const bar = $('#actions');
    bar.replaceChildren();
    const card = deck ? currentCard() : null;
    if (!card || (prefs.study === 'test' && session.finished)) return;
    const id = card.id;
    const prev = h('button', { class: 'btn small', onclick: () => move(-1), 'aria-label': 'Previous card' }, '‹');
    const next = h('button', { class: 'btn small', onclick: () => move(1), 'aria-label': 'Next card' }, '›');
    if (prefs.study === 'learn') {
        bar.append(prev,
            h('button', {
                class: 'btn' + (progress.known.has(id) ? ' on-known' : ''),
                onclick: () => { progress.toggleKnown(id); render(); },
            }, progress.known.has(id) ? '✓ Known' : 'Known'),
            h('button', {
                class: 'btn' + (progress.review.has(id) ? ' on-review' : ''),
                onclick: () => { progress.toggleReview(id); render(); },
            }, progress.review.has(id) ? '⚑ Review' : 'Review'),
            next);
    } else if (!session.flipped) {
        bar.append(prev,
            h('button', { class: 'btn primary', onclick: reveal }, card.kind === 'build' ? 'Show the build' : 'Show answer'),
            h('button', { class: 'btn small', onclick: () => move(1) }, 'Skip ›'));
    } else {
        bar.append(prev,
            h('button', { class: 'btn bad', onclick: () => answer(false) }, '✗ Missed it'),
            h('button', { class: 'btn good', onclick: () => answer(true) }, '✓ Got it'),
            h('button', { class: 'btn small', onclick: () => move(1), 'aria-label': 'Skip' }, '›'));
    }
}

function addSwipe(el) {
    let x0 = null, y0 = null;
    el.addEventListener('touchstart', (e) => {
        x0 = e.touches[0].clientX;
        y0 = e.touches[0].clientY;
    }, { passive: true });
    el.addEventListener('touchend', (e) => {
        if (x0 == null) return;
        const dx = e.changedTouches[0].clientX - x0;
        const dy = e.changedTouches[0].clientY - y0;
        x0 = null;
        if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) move(dx < 0 ? 1 : -1);
    });
}

// ---- Brick peek ----

function openPeek(card) {
    const dialog = $('#brick-dialog');
    const info = groupsByKey[groupKey(card.module, card.group)];
    dialog.replaceChildren(
        h('div', { class: 'dialog-body', style: { '--accent': colorOf(card) } },
            h('div', { class: 'badges' }, h('span', { class: 'label' }, h('span', { class: 'stud' }), h('span', {}, info?.group.label ?? ''))),
            h('h2', {}, card.title),
            card.subtitle && h('p', {}, card.subtitle),
            card.lego && h('p', { class: 'peek-lego' }, card.lego),
            h('p', { class: 'peek-summary' }, card.summary)),
        h('div', { class: 'dialog-actions' },
            h('button', { class: 'btn primary', onclick: () => dialog.close() }, 'Close')));
    dialog.showModal();
}

// ---- Notes ----

function openNotes(card) {
    const dialog = $('#notes-dialog');
    const area = h('textarea', { placeholder: card.kind === 'build'
        ? 'What did you build? What broke, and how did you patch it?'
        : 'A mnemonic, a gotcha, a link to your own write-up…' }, notes[card.id] ?? '');
    const persist = (text) => {
        text = text.trim();
        if (text) notes[card.id] = text; else delete notes[card.id];
        saved.set('notes', notes);
        dialog.close();
        render();
    };
    dialog.replaceChildren(
        h('div', { class: 'dialog-body' },
            h('h2', {}, `Notes · ${card.title}`),
            h('p', {}, 'Notes stay on this device. Export them as a build journal from the menu.'),
            area),
        h('div', { class: 'dialog-actions' },
            notes[card.id] && h('button', { class: 'btn bad', onclick: () => persist('') }, 'Delete'),
            h('button', { class: 'btn', onclick: () => dialog.close() }, 'Cancel'),
            h('button', { class: 'btn primary', onclick: () => persist(area.value) }, 'Save')));
    dialog.showModal();
    area.focus();
}

function download(name, type, text) {
    const blob = new Blob([text], { type });
    const a = h('a', { href: URL.createObjectURL(blob), download: name });
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

function exportJournal() {
    const lines = ['# System Legos — Build Journal', '', `Exported ${new Date().toLocaleString()}`, ''];
    for (const m of deck.modules) {
        const cards = deck.cards.filter((c) => c.module === m.id && notes[c.id]);
        if (!cards.length) continue;
        lines.push(`## ${m.title}`, '');
        for (const c of cards) {
            lines.push(`### ${c.title}`, '', `*${groupsByKey[groupKey(c.module, c.group)]?.group.label ?? c.group}*`, '', notes[c.id], '');
        }
    }
    download('System Legos Journal.md', 'text/markdown', lines.join('\n'));
}

function importNotes() {
    const input = h('input', { type: 'file', accept: '.json,application/json' });
    input.addEventListener('change', async () => {
        const file = input.files[0];
        if (!file) return;
        try {
            const data = JSON.parse(await file.text());
            if (typeof data !== 'object' || Array.isArray(data)) throw new Error('expected an object of card id → note');
            const added = Object.entries(data).filter(([k, v]) => byId[k] && typeof v === 'string' && v.trim());
            for (const [k, v] of added) notes[k] = v.trim();
            saved.set('notes', notes);
            alert(`Imported notes for ${added.length} card${added.length === 1 ? '' : 's'}.`);
            render();
        } catch (err) {
            alert(`Could not import notes: ${err.message}`);
        }
    });
    input.click();
}

// ---- Drawer: modules and options ----

function openDrawer() {
    renderDrawer();
    $('#drawer').classList.add('open');
    $('#drawer').setAttribute('aria-hidden', 'false');
    $('#backdrop').hidden = false;
}

function closeDrawer() {
    $('#drawer').classList.remove('open');
    $('#drawer').setAttribute('aria-hidden', 'true');
    $('#backdrop').hidden = true;
}

function checkRow(label, checked, onchange, extra) {
    const id = 'c' + Math.random().toString(36).slice(2);
    return h('div', { class: 'row' },
        h('input', { type: 'checkbox', id, checked, onchange: (e) => onchange(e.target.checked) }),
        h('label', { for: id }, label),
        extra);
}

function renderDrawer() {
    const body = $('#drawer-body');
    const scroll = body.scrollTop;
    body.replaceChildren();
    if (!deck) return;

    const practice = h('select', { onchange: (e) => { setPref('practice', e.target.value); rebuild(); } },
        [['all', 'All cards'], ['notKnown', 'Not yet known'], ['review', 'Review only']]
            .map(([v, t]) => h('option', { value: v, selected: prefs.practice === v }, t)));
    body.append(h('h4', {}, 'Practice'), h('div', { class: 'panel' },
        h('div', { class: 'row' }, h('span', { class: 'grow' }, 'Cards'), practice),
        checkRow('Shuffle', prefs.shuffle, (on) => { setPref('shuffle', on); rebuild(); }),
        h('button', { class: 'menu-btn', onclick: () => { rebuild(); closeDrawer(); } }, '↺ Restart from the first card')));

    const selected = selectedSet();
    const toggle = (keys, on) => {
        for (const k of keys) on ? selected.add(k) : selected.delete(k);
        setSelected(selected);
        rebuild();
    };
    const countIn = (m, g) => deck.cards.filter((c) => c.kind === prefs.kind && c.module === m && c.group === g).length;
    body.append(h('h4', {}, `Practice these ${NOUNS[prefs.kind]}`));
    for (const m of deck.modules) {
        const groups = m.groups.filter((g) => countIn(m.id, g.id) > 0);
        if (!groups.length) continue;
        const keys = groups.map((g) => groupKey(m.id, g.id));
        const collapsed = prefs.collapsed.includes(m.id);
        const count = keys.filter((k) => selected.has(k)).length;
        body.append(h('div', { class: 'panel', style: { marginBottom: '10px' } },
            h('button', {
                class: 'source-head' + (collapsed ? ' collapsed' : ''),
                onclick: () => {
                    const set = new Set(prefs.collapsed);
                    collapsed ? set.delete(m.id) : set.add(m.id);
                    setPref('collapsed', [...set]);
                    renderDrawer();
                },
            }, h('span', { class: 'chev' }, '▾'), m.title, h('span', { class: 'count' }, `${count}/${keys.length}`)),
            !collapsed && h('div', { class: 'links' },
                h('button', { onclick: () => toggle(keys, true) }, 'Select all'),
                h('button', { onclick: () => toggle(keys, false) }, 'Clear')),
            !collapsed && groups.map((g, i) =>
                checkRow(
                    h('span', { style: { display: 'flex', alignItems: 'center', gap: '8px' } },
                        h('span', { class: 'stud', style: { '--dot': colorNamed(g.color) } }), g.label),
                    selected.has(keys[i]),
                    (on) => toggle([keys[i]], on),
                    h('span', { class: 'count' }, countIn(m.id, g.id))))));
    }

    const noteCount = Object.keys(notes).filter((k) => byId[k]).length;
    body.append(h('h4', {}, 'More'), h('div', { class: 'panel' },
        h('button', { class: 'menu-btn', onclick: () => { closeDrawer(); openPrint(); } }, '🖨 Print / Save as PDF'),
        h('button', { class: 'menu-btn', onclick: exportJournal, disabled: noteCount === 0 },
            `⤓ Export build journal (${noteCount} note${noteCount === 1 ? '' : 's'})`),
        h('button', { class: 'menu-btn', onclick: () => download('notes.json', 'application/json', JSON.stringify(notes, null, 2) + '\n'), disabled: noteCount === 0 },
            '⤓ Back up notes (notes.json)'),
        h('button', { class: 'menu-btn', onclick: importNotes }, '⤒ Import notes (notes.json from the Mac app)'),
        h('button', {
            class: 'menu-btn danger',
            onclick: () => {
                if (!confirm('Clear every Known and Review mark?')) return;
                progress.known.clear();
                progress.review.clear();
                progress.save();
                rebuild();
            },
        }, 'Reset progress'),
        h('a', { class: 'menu-btn', href: 'https://github.com/venkatacrc/systemlegos', target: '_blank', rel: 'noopener' }, '⌥ Source and Mac app on GitHub')));

    $('#drawer-foot').textContent = `${session.order.length} ${NOUNS[prefs.kind]} selected`;
    body.scrollTop = scroll;
}

// ---- Print / PDF ----

function cardsToPrint(opts) {
    const selected = selectedSet();
    return deck.cards.filter((c) =>
        selected.has(groupKey(c.module, c.group))
        && (c.kind === 'brick' ? opts.bricks : opts.builds)
        && (!opts.reviewOnly || progress.review.has(c.id)));
}

function openPrint() {
    if (!deck) return;
    const dialog = $('#print-dialog');
    const opts = { ...prefs.print };
    const countLine = h('p', {});
    const printBtn = h('button', { class: 'btn primary', onclick: () => { dialog.close(); printCards(opts); } },
        'Print / Save as PDF');
    const update = () => {
        saved.set('print', opts);
        prefs.print = { ...opts };
        const n = cardsToPrint(opts).length;
        countLine.textContent = n
            ? `${n} card${n === 1 ? '' : 's'} from the groups ticked in the menu. In the print screen, choose “Save as PDF” to make a PDF.`
            : 'No cards to print. Tick some groups in the menu, or turn off “Only cards marked for review”.';
        printBtn.disabled = n === 0;
    };
    const opt = (key, label) => checkRow(label, opts[key], (on) => { opts[key] = on; update(); });
    dialog.replaceChildren(
        h('div', { class: 'dialog-body' },
            h('h2', {}, 'Print a study guide'),
            countLine,
            h('h4', {}, 'Cards'),
            h('div', { class: 'panel' }, opt('bricks', 'Bricks'), opt('builds', 'Builds')),
            h('h4', {}, 'Include'),
            h('div', { class: 'panel' },
                opt('details', 'Steps, sections and bricks used'), opt('links', 'Reading links'), opt('notes', 'My notes')),
            h('h4', {}, 'Which cards'),
            h('div', { class: 'panel' }, opt('reviewOnly', 'Only cards marked for review'))),
        h('div', { class: 'dialog-actions' },
            h('button', { class: 'btn', onclick: () => dialog.close() }, 'Cancel'),
            printBtn));
    update();
    dialog.showModal();
}

function printCards(opts) {
    const cards = cardsToPrint(opts);
    const area = $('#print-area');
    area.replaceChildren(
        h('h1', {}, 'System Legos'),
        h('div', { class: 'count' }, `${cards.length} card${cards.length === 1 ? '' : 's'}`));
    let last = null;
    for (const c of cards) {
        const info = groupsByKey[groupKey(c.module, c.group)];
        const head = `${info.module.title} — ${info.group.label}`;
        if (head !== last) {
            area.append(h('h2', {}, head));
            last = head;
        }
        area.append(h('div', { class: 'pc' },
            h('div', { class: 'pc-title' }, c.title),
            c.subtitle && h('div', { class: 'pc-sub' }, c.subtitle),
            c.lego && h('div', { class: 'pc-lego' }, c.lego),
            h('p', {}, h('b', {}, c.kind === 'build' ? 'PROBLEM  ' : 'WHAT IT IS  '), c.summary),
            opts.details && c.steps?.length && [h('b', {}, 'ASSEMBLY'), h('ol', {}, c.steps.map((s) => h('li', {}, s)))],
            opts.details && c.uses?.length && h('p', {}, h('b', {}, 'BRICKS  '), c.uses.map((u) => byId[u]?.title ?? u).join(' · ')),
            opts.details && c.sections.map((s) => [h('b', {}, s.title.toUpperCase()), h('ul', {}, s.items.map((i) => h('li', {}, i)))]),
            opts.links && c.links.length && [h('b', {}, 'READ IN DEPTH'),
                h('ul', { class: 'pc-links' }, c.links.map((r) => h('li', {}, `${r.title} — ${r.url}`)))],
            opts.notes && notes[c.id] && h('p', {}, h('b', {}, 'MY NOTES  '), notes[c.id])));
    }
    const oldTitle = document.title;
    document.title = 'System Legos study guide';
    window.addEventListener('afterprint', () => { document.title = oldTitle; }, { once: true });
    window.print();
}

// ---- Wiring ----

for (const [id, key] of [['#kind-switch', 'kind'], ['#study-switch', 'study']]) {
    $(id).addEventListener('click', (e) => {
        const value = e.target.closest('button')?.dataset.value;
        if (!value || value === prefs[key] || !deck) return;
        setPref(key, value);
        rebuild();
    });
}

$('#open-drawer').addEventListener('click', openDrawer);
$('#close-drawer').addEventListener('click', closeDrawer);
$('#backdrop').addEventListener('click', closeDrawer);
$('#open-print').addEventListener('click', openPrint);
for (const d of document.querySelectorAll('dialog')) {
    d.addEventListener('click', (e) => { if (e.target === d) d.close(); });
}

document.addEventListener('keydown', (e) => {
    if (e.metaKey || e.ctrlKey || e.altKey) {
        if ((e.metaKey || e.ctrlKey) && e.key === 'p' && deck) {
            e.preventDefault();
            openPrint();
        }
        return;
    }
    if (e.key === 'Escape') { closeDrawer(); return; }
    if (document.querySelector('dialog[open]') || e.target.matches('input, textarea, select')) return;
    const card = deck ? currentCard() : null;
    if (!card || session.finished) return;
    const test = prefs.study === 'test';
    const actions = {
        ArrowLeft: () => move(-1),
        ArrowRight: () => move(1),
        ' ': () => reveal(),
        g: () => test && answer(true),
        m: () => test && answer(false),
        k: () => { if (!test) { progress.toggleKnown(card.id); render(); } },
        r: () => { if (!test) { progress.toggleReview(card.id); render(); } },
        n: () => openNotes(card),
    };
    const run = actions[e.key.length === 1 ? e.key.toLowerCase() : e.key];
    if (run) {
        e.preventDefault();
        run();
    }
});

render();

fetch('deck.json')
    .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
    })
    .then((data) => {
        deck = data;
        indexDeck();
        rebuild();
    })
    .catch((err) => {
        loadError = `Open this page once while online so the cards can be saved for offline use. (${err.message})`;
        render();
    });

if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').catch(() => {});
}
