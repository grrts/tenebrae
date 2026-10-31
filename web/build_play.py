import re, sys
src = open('tenebrae-pitch.html').read()
head = src[:src.index('<style>')]
head = head.replace('<title>Tenebrae Pitch Sheet</title>', '<title>Tenebrae Playtest</title>')
script = src[src.index('<script>'):]
lines = script.split('\n')

def rep(a, b, n=1):
    global script
    c = script.count(a)
    if c != n: sys.exit(f'COUNT {c} for: {a[:80]}')
    script = script.replace(a, b)

# --- input layer, defined before everything else
rep('<script>\n(() => {', r'''<script>
(() => {
/* ---------- input: keyboard + gamepad ---------- */
const KEYS = { left: ['KeyA', 'ArrowLeft'], right: ['KeyD', 'ArrowRight'], up: ['KeyW', 'ArrowUp'], down: ['KeyS', 'ArrowDown'],
  jump: ['Space', 'KeyZ', 'KeyK'], attack: ['KeyJ', 'KeyX'], dash: ['ShiftLeft', 'ShiftRight', 'KeyL', 'KeyC'] };
const held = new Set(), IN = {}, PR = {}, prevIN = {};
addEventListener('keydown', e => { if (Object.values(KEYS).flat().includes(e.code)) e.preventDefault(); held.add(e.code); });
addEventListener('keyup', e => held.delete(e.code));
addEventListener('blur', () => held.clear());
function pollInput() {
  const pad = (navigator.getGamepads ? [...navigator.getGamepads()] : []).find(g => g);
  const b = i => !!(pad && pad.buttons[i] && pad.buttons[i].pressed), ax = i => pad ? pad.axes[i] || 0 : 0;
  const now = {
    left: b(14) || ax(0) < -.4, right: b(15) || ax(0) > .4, up: b(12) || ax(1) < -.5, down: b(13) || ax(1) > .5,
    jump: b(0), attack: b(2), dash: b(5) || b(7) || b(1) };
  for (const k in KEYS) { IN[k] = now[k] || KEYS[k].some(c => held.has(c)); PR[k] = IN[k] && !prevIN[k]; prevIN[k] = IN[k]; }
}
''')
rep("const ZM = 1.3, DA = ARENAS[1], DW = 960, DH = 600, FLOOR = DA.h - TS, GRV = 2100, PS = .66, DEPTH_T = 10;",
    "const ZM = 1.3, DA = ARENAS[1], DW = 960, DH = 600, FLOOR = DA.h - TS, GRV = 2100, PS = .66, DEPTH_T = 40;")

# --- overlays wait for the player instead of an AI pick
rep("function openDraft(st) {", "function interactive(o) { o.at = 1e9; o.dur = 1e9; o.pick = Math.max(0, o.pick); return o; }\nfunction openDraft(st) {")
rep("  st.ov = { kind: 'weapon', t: 0, at: 1.9, dur: 2.8, opts: [a, b], pick:", "  st.ov = interactive({ kind: 'weapon', t: 0, at: 1.9, dur: 2.8, opts: [a, b], pick:")
rep("st.rng() < .5 ? 0 : 1 };\n}", "st.rng() < .5 ? 0 : 1 });\n}")
rep("  st.ov = { kind: 'draft', t: 0, at: 1.8, dur: 2.7, opts, pick: sc.indexOf(Math.max(...sc)), lvl: st.lvl };",
    "  st.ov = interactive({ kind: 'draft', t: 0, at: 1.8, dur: 2.7, opts, pick: sc.indexOf(Math.max(...sc)), lvl: st.lvl });")
rep("  st.ov = { kind: 'shop', t: 0, at: 1.8, dur: 2.7, opts, pick };", "  st.ov = interactive({ kind: 'shop', t: 0, at: 1.8, dur: 2.7, opts, pick });")
rep("  st.ov = { kind: 'over', t: 0, dur: 7.5,", "  st.ov = { kind: 'over', t: 0, dur: 30,")
rep("""    const o = st.ov; o.t += rdt;
""", """    const o = st.ov; o.t += rdt;
    if (o.kind !== 'over' && o.t < o.at && o.t > .35) {
      const n = o.opts.length;
      if (PR.left) o.pick = (o.pick + n - 1) % n;
      if (PR.right) o.pick = (o.pick + 1) % n;
      if (PR.jump || PR.attack) { o.at = o.t; o.dur = o.t + .9; }
      else if (PR.dash && o.kind === 'shop') { o.pick = -1; o.at = o.t; o.dur = o.t + .9; }
    } else if (o.kind === 'over' && o.t > 2.5 && (PR.jump || PR.attack)) o.dur = o.t;
""")
rep("decided = t >= o.at;", "decided = t >= o.at, live_ = !decided;")
rep("const hov = decided ? o.pick : Math.floor(t / .3) % n;", "const hov = decided ? o.pick : Math.max(0, o.pick);")
rep("txt(o.kind === 'draft' ? 'A  DRAFT     Y  REROLL ◆ 40     B  SKIP FOR WAX' : o.kind === 'shop' ? 'A  BUY     B  LEAVE' : 'A  EQUIP'",
    "txt(o.kind === 'shop' ? '← →  CHOOSE     J / SPACE  BUY     SHIFT  LEAVE' : '← →  CHOOSE     J / SPACE  CONFIRM'")
rep("txt(`NEW RUN IN ${Math.max(1, Math.ceil(o.dur - t))} · NEW SEED · NEW DRAWS`", "txt(t > 2.5 ? 'PRESS J OR SPACE TO RELIGHT THE CANDLES · NEW SEED · NEW DRAWS' : 'LIGHTS OUT'")

# --- player control replaces the AI
start = script.index("      if (p.pre > 0) dir = p.vx > 60 ? 1 : p.vx < -60 ? -1 : 0;")
end = script.index("      if (p.kick <= 0) { const sp = p.atk ? 80 : 310;")
script = script[:start] + r'''      // ---- player control ----
      dir = (IN.right ? 1 : 0) - (IN.left ? 1 : 0);
      if (p.ground) { p.dj = false; p.coy = .1; } else p.coy = Math.max(0, (p.coy || 0) - dt);
      p.buf = PR.jump ? .12 : Math.max(0, (p.buf || 0) - dt);
      if (PR.dash && p.dashCd <= 0 && !(p.airDash && !p.ground)) {
        if (dir) p.f = dir; p.dash = .2; p.dashCd = has(st, 'GALE STEP') ? .45 : .6; st.dashId++; p.atk = null; if (!p.ground) p.airDash = true;
      }
      if (p.ground) p.airDash = false;
      if (PR.attack) {
        if (!p.ground && IN.down) { p.slam = true; p.atk = null; }
        else if (!p.atk) { p.atk = { step: 0, t: 0, hit: false, q: false }; if (dir) p.f = dir; }
        else p.atk.q = true;
      }
      if (!p.ground && p.wall && p.wall === dir && p.vy > 0) {
        p.vy = Math.min(p.vy, 170); p.slideT += dt;
        if (Math.random() < dt * 30) sparks(st.P, p.x + p.wall * 8, p.y - 30, .4, 1);
      } else p.slideT = 0;
      if (p.buf > 0) {
        if (p.ground && IN.down && p.plat === 'one') { p.buf = 0; p.dropT = .22; p.ground = false; p.vy = 80; }
        else if (p.ground || p.coy > 0) { p.buf = 0; p.coy = 0; p.vy = -800; p.ground = false; p.stretch = .16; dust(); }
        else if (p.wall) {
          const wl = p.wall; p.buf = 0; p.vy = -800; p.vx = -wl * 430; p.f = -wl; p.kick = .22; p.dj = false; p.slideT = 0;
          for (let i = 0; i < 8; i++) emit(st.P, { x: p.x + wl * 8, y: p.y - 10, vx: -wl * rnd(20, 120), vy: rnd(-60, 60), drag: 3, r: rnd(3, 6), col: 'rgba(170,120,105,.35)', life: .4, shrink: 1 });
          if (has(st, 'UPDRAFT')) { st.rings.push({ x: p.x + wl * 8, y: p.y - 30, t: 0, kind: 'gale' }); st.shake = .12; for (const e of live) if (Math.abs(e.x - p.x) < 160 && Math.abs(e.y - p.y) < 170) hurt(e, 2, -wl * 220, -720, true); }
          if (sigCount(st, 'GALE') >= 3) p.dashCd = 0;
        } else if (!p.dj) {
          p.buf = 0; p.vy = -760; p.dj = true; p.flip = .4; st.rings.push({ x: p.x, y: p.y, t: 0, kind: 'puff' }, { x: p.x, y: p.y + 4, t: 0, kind: 'wing', f: p.f });
          for (let i = 0; i < 12; i++) { const a = rnd(0, TAU), v = rnd(50, 130); emit(st.P, { x: p.x, y: p.y, vx: Co(a) * v, vy: S(a) * v * .4 + 30, drag: 3, r: rnd(2.5, 5), col: i % 3 ? '#1b0c10' : C.crimson, glow: i % 3 ? 0 : 6, life: rnd(.35, .6), shrink: 1 }); }
          if (has(st, 'ECHO STEP')) { st.shades.push({ x: p.x, y: p.y, f: p.f, t: 0 }); for (const e of live) if (Math.hypot(e.x - p.x, e.y - e.h / 2 - p.y + 28) < 115) hurt(e, 2, p.f * 200, -300, true); }
        }
      }
      if (!IN.jump && p.vy < -300 && p.flip <= 0 && p.kick <= 0 && !p.cut) { p.vy *= .5; p.cut = true; }
      if (p.ground || p.vy >= 0) p.cut = false;
''' + script[end:]
rep("a.t += dt; if (a.t > stepT) { a.step++; a.t = 0; a.hit = false; if (a.step > 2) p.atk = null; }",
    "a.t += dt; if (a.t > stepT) { if (a.q && a.step < 2) { a.step++; a.t = 0; a.hit = false; a.q = false; } else if (a.t > stepT + .12 || a.step >= 2) p.atk = null; }")
# the AI's auto camera dodge etc. stay harmless; input is polled once per frame
rep("function arenaSim(ctx, rdt, r) {\n", "function arenaSim(ctx, rdt, r) {\n  pollInput();\n")
# control hints in HUD
rep("[['DASH', 'RB', Math.max(0, p.dashCd) / 1.2], ['SLAM', '↓X', 0], ['WALL', 'A', 0]]", "[['DASH', 'SHIFT', Math.max(0, p.dashCd) / .6], ['SLAM', 'S+J', 0], ['WALL', 'SPACE', 0]]")
# run always: no observer pausing for a single full-page canvas
rep("R.forEach(r => io && io.observe(r.cv));", "")


# --- braziers: strike one to relight it for 20 s (+15% damage, more light). Unlit ones burn low.
rep("function arenaSim(ctx, rdt, r) {\n", """function brKey(bx, by) { return bx + ',' + by; }
function brState(st) { if (st.brRun !== st.run) { st.brRun = st.run; st.brT = {}; } return st.brT; }
function brLit(st, bx, by) { return (brState(st)[brKey(bx, by)] || 0) > st.time; }
function brBuff(st) { const T = brState(st); for (const k in T) if (T[k] > st.time) return true; return false; }
function arenaSim(ctx, rdt, r) {
""")
rep("  const hurt = (e, dmg, kx, ky, crit) => {\n", "  const hurt = (e, dmg, kx, ky, crit) => {\n    if (brBuff(st)) dmg *= 1.15;\n")
rep("      if (!a.hit) { a.hit = true;", """      if (!a.hit) { const T = brState(st);
        for (const [bx, by] of DA.braz) { const dx = (bx - p.x) * p.f;
          if (dx > -20 && dx < REACH[st.weapon] + 10 && Math.abs(by - (p.y - 28)) < 80 && !(T[brKey(bx, by)] > st.time + 19)) {
            T[brKey(bx, by)] = st.time + 20; sparks(st.P, bx, by - 8, 1.2, 18); st.rings.push({ x: bx, y: by - 8, t: 0, kind: 'ember' });
            st.banner = { text: 'BRAZIER RELIT', sub: '+15% DAMAGE AND MORE LIGHT FOR 20 S', t: 1.2, col: C.gold }; } }
      }
      if (!a.hit) { a.hit = true;""")
rep("const fl = .8 + S(st.time * 13 + bx) * .1 + S(st.time * 7.3 + by) * .1;", "const fl = (.8 + S(st.time * 13 + bx) * .1 + S(st.time * 7.3 + by) * .1) * (brLit(st, bx, by) ? 1.5 : .6);")
rep("ctx.beginPath(); ctx.ellipse(bx + sd * 9, by - 6, 5, 9 + S(st.time * 14 + by) * 2, 0, 0, TAU); ctx.fill(); ctx.restore();",
    "const bk = brLit(st, bx, by) ? 1.6 : .65; ctx.beginPath(); ctx.ellipse(bx + sd * 9, by - 6 * bk, 5 * bk, (9 + S(st.time * 14 + by) * 2) * bk, 0, 0, TAU); ctx.fill(); ctx.restore();")
rep("r0 = lerp(460, 140, k);", "r0 = lerp(460, 140, k) * (brBuff(st) ? 1.35 : 1);")
rep("      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);\n    }\n  }\n", """      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      // relit braziers push the dark back around themselves
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (const [bx, by] of DA.braz) if (brLit(st, bx, by)) {
        const qx = (bx - st.cam.x) * ZM + W / 2, qy = (by - st.cam.y) * ZM + H / 2, rr = 260 * ZM;
        if (qx < -rr || qx > W + rr || qy < -rr || qy > H + rr) continue;
        const gg = ctx.createRadialGradient(qx, qy, 0, qx, qy, rr); gg.addColorStop(0, `rgba(255,150,80,${.35 * k})`); gg.addColorStop(1, 'rgba(255,150,80,0)');
        ctx.fillStyle = gg; ctx.fillRect(qx - rr, qy - rr, rr * 2, rr * 2); }
      ctx.restore();
    }
  }
""")

page = head + r'''<style>
  :root { --bg: #070506; --text: #f3ebe0; --muted: #9a9289; }
  html, body { margin: 0; height: 100%; background: var(--bg); color: var(--text); overflow: hidden; }
  body { display: flex; flex-direction: column; align-items: center; justify-content: center; font: 500 13px "IBM Plex Mono", ui-monospace, monospace; }
  #cv-demo { width: min(100vw, calc((100vh - 44px) * 1.6)); aspect-ratio: 960 / 600; height: auto; display: block; outline: none; }
  .keys { padding: 10px 16px; color: var(--muted); text-align: center; letter-spacing: .04em; line-height: 1.6; }
  .keys b { color: var(--text); font-weight: 600; }
</style>
<canvas id="cv-demo" tabindex="0" aria-label="Tenebrae playtest"></canvas>
<div class="keys"><b>A D</b> move · <b>SPACE</b> jump, double jump, wall jump · <b>J</b> attack (tap for combo) · <b>S + J</b> in air: slam · <b>SHIFT</b> dash · <b>S + SPACE</b> drop · controller works too</div>
''' + script
open('tenebrae-play.html', 'w').write(page)
print('ok', len(page))
