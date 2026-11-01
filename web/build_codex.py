# Adds the Codex to tenebrae-play.html: the 22 lore pages from src/codex.gd unlock
# as you meet places, foes and bosses (kept per browser), and TAB (or the pad's
# Back button) opens them over the game, paused. build_play.py runs this last.
import json, re, sys

def _codex_build():
    path = 'tenebrae-play.html'
    page = open(path).read()
    if 'const CODEX = ' in page:
        sys.exit('build_codex: already applied; run build_play.py for a fresh build')

    gd = open('../src/codex.gd').read()
    entries = [{'id': m[0], 'cat': m[1], 'name': m[2], 'text': m[3]} for m in re.findall(
        r'\{"id": "([^"]+)", "cat": (\w+), "name": "([^"]+)",\s*"text": "([^"]+)"\}', gd)]
    if len(entries) < 20:
        sys.exit(f'build_codex: only parsed {len(entries)} entries from src/codex.gd')

    def rep(a, b, n=1):
        nonlocal page
        c = page.count(a)
        if c != n:
            sys.exit(f'build_codex: COUNT {c} for: {a[:90]}')
        page = page.replace(a, b)

    rep("function arenaSim(ctx, rdt, r) {\n", """const CODEX = (() => {
  const E = """ + json.dumps(entries) + """;
  const COL = { LORE: '#f2b43a', PLACE: '#3fd6c4', FOE: '#e5383b', BOSS: '#b44dff' };
  let got = {}, open = false, pick = 0, toasts = [], prev = {};
  try { got = JSON.parse(localStorage.getItem('wickbearer.codex') || '{}') || {}; } catch (e) { got = {}; }
  const keyQ = [];
  addEventListener('keydown', e => {
    if (e.code === 'Tab') { e.preventDefault(); open = !open; }
    else if (open && ['ArrowUp', 'KeyW', 'ArrowDown', 'KeyS', 'ShiftLeft', 'ShiftRight'].includes(e.code)) { e.preventDefault(); e.stopImmediatePropagation(); keyQ.push(e.code); }
  }, true);
  function learn(id) {
    if (got[id]) return; const e = E.find(x => x.id === id); if (!e) return;
    got[id] = 1; try { localStorage.setItem('wickbearer.codex', JSON.stringify(got)); } catch (er) {}
    toasts.push({ name: e.name, t: 0 });
  }
  const count = () => E.filter(e => got[e.id]).length;
  // returns true while the Codex is open, so the game pauses under it
  function step() {
    const pad = (navigator.getGamepads ? [...navigator.getGamepads()] : []).find(g => g);
    const b = i => !!(pad && pad.buttons[i] && pad.buttons[i].pressed), now = { back: b(8), up: b(12), down: b(13), close: b(1) };
    const pr = k => now[k] && !prev[k]; const ev = { up: pr('up'), down: pr('down'), close: pr('close') };
    if (pr('back')) open = !open;
    prev = now;
    for (const c of keyQ.splice(0)) { if (c === 'ArrowUp' || c === 'KeyW') ev.up = true; else if (c === 'ArrowDown' || c === 'KeyS') ev.down = true; else ev.close = true; }
    if (open) {
      if (ev.up) pick = (pick + E.length - 1) % E.length;
      if (ev.down) pick = (pick + 1) % E.length;
      if (ev.close) open = false;
    }
    return open;
  }
  function wrap(ctx, s, mw) { const out = []; let line = ''; for (const w of s.split(' ')) { const t = line ? line + ' ' + w : w; if (ctx.measureText(t).width > mw && line) { out.push(line); line = w; } else line = t; } out.push(line); return out; }
  function draw(ctx, W, H, dt) {
    const T = (s, x, y, f, c, al = 'left') => { ctx.font = f; ctx.textAlign = al; ctx.lineWidth = 3; ctx.strokeStyle = '#000'; ctx.strokeText(s, x, y); ctx.fillStyle = c; ctx.fillText(s, x, y); };
    toasts = toasts.filter(t => (t.t += dt) < 3.6);
    toasts.forEach((t, i) => {
      const a = Math.max(0, Math.min(1, t.t * 4, (3.6 - t.t) * 2)), x = W - 276, y = H - 150 - i * 52;
      ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = 'rgba(8,6,10,.92)'; ctx.fillRect(x, y, 260, 44); ctx.strokeStyle = '#f2b43a'; ctx.lineWidth = 1.2; ctx.strokeRect(x, y, 260, 44);
      T('NEW IN THE CODEX · TAB', x + 12, y + 17, `600 10px ${MONO}`, '#f2b43a'); T(t.name, x + 12, y + 36, `700 15px ${MONO}`, '#f3ebe0'); ctx.restore();
    });
    if (!open) return;
    ctx.save(); ctx.fillStyle = 'rgba(4,3,5,.95)'; ctx.fillRect(0, 0, W, H);
    T('THE CODEX', W / 2, 54, `900 34px ${DISP}`, '#f3ebe0', 'center');
    T(`${count()} OF ${E.length} PAGES · EVERYTHING THE DARK HAS SHOWN YOU`, W / 2, 76, `600 11px ${MONO}`, '#3fd6c4', 'center');
    const rows = 15, top = Math.max(0, Math.min(pick - 7, E.length - rows)), x0 = 40;
    for (let j = 0; j < Math.min(rows, E.length); j++) {
      const i = top + j, e = E[i], y = 98 + j * 28, known = got[e.id];
      if (i === pick) { ctx.fillStyle = 'rgba(30,22,34,1)'; ctx.fillRect(x0, y, 280, 24); ctx.strokeStyle = '#f2b43a'; ctx.lineWidth = 1.5; ctx.strokeRect(x0, y, 280, 24); }
      T(e.cat, x0 + 8, y + 16, `600 9px ${MONO}`, COL[e.cat]);
      T(known ? e.name : '? ? ?', x0 + 60, y + 17, `600 13px ${MONO}`, known ? '#f3ebe0' : '#5d5752');
    }
    const s = E[pick], bx = 350, bw = W - bx - 40;
    ctx.fillStyle = 'rgba(14,11,16,1)'; ctx.fillRect(bx, 98, bw, 412);
    if (got[s.id]) {
      T(s.name, bx + 22, 136, `900 22px ${DISP}`, COL[s.cat]);
      ctx.font = `500 15px ${MONO}`; wrap(ctx, s.text, bw - 44).forEach((l, i) => T(l, bx + 22, 172 + i * 23, `500 15px ${MONO}`, '#d8d0c6'));
    } else { T('This page is still dark.', bx + 22, 136, `600 17px ${MONO}`, '#7d766f'); T('Keep descending.', bx + 22, 162, `500 13px ${MONO}`, '#5d5752'); }
    T('↑ ↓  CHOOSE      TAB / SHIFT  BACK', W / 2, H - 22, `600 11px ${MONO}`, '#7d766f', 'center');
    ctx.restore();
  }
  return { learn, step, draw, count, E };
})();
function arenaSim(ctx, rdt, r) {
""")
    rep("mount('cv-demo', DW, DH, (ctx, t, dt, r) => arenaSim(ctx, dt, r),",
        "mount('cv-demo', DW, DH, (ctx, t, dt, r) => { const cOpen = CODEX.step(); arenaSim(ctx, cOpen ? 0 : dt, r); CODEX.draw(ctx, r.W, r.H, cOpen ? 0 : dt); },")
    # what unlocks each page
    rep("    e.dead = true; st.kills++;\n", """    e.dead = true; st.kills++;
    CODEX.learn(e.type === 'boss' ? 'boss_' + Math.min(3, Math.floor((st.depth - 1) / 4)) : 'foe_' + { sh: 0, bat: 1, br: 2, sp: 3, dr: 4, fg: 5, sn: 6 }[e.type]);
    if (e.elite) CODEX.learn('elite');
    if (e.type === 'boss' && st.depth >= 5 && st.depth < 9) CODEX.learn('umber');
""")
    rep("st.dp = 0; st.depth++; STORY.onDepth(st);", "st.dp = 0; st.depth++; STORY.onDepth(st); CODEX.learn('hush'); CODEX.learn('place_' + Math.min(3, Math.floor((st.depth - 1) / 4)));")
    rep("  STORY.onBossSpawn(st);\n", "  STORY.onBossSpawn(st); CODEX.learn('strepitus');\n")
    rep("if (o.kind === 'weapon') { st.weapon = v;", "if (o.kind === 'weapon') { CODEX.learn('norrow'); CODEX.learn('hild'); CODEX.learn('place_0'); st.weapon = v;")
    rep("end3: st => { st.victory = true;", "end3: st => { CODEX.learn('dawn'); st.victory = true;")
    rep("<b>S + SPACE</b> drop ·", "<b>S + SPACE</b> drop · <b>TAB</b> the Codex ·")
    open(path, 'w').write(page)
    print('codex ok', len(page), len(entries), 'pages')

_codex_build()
