# Swaps the playtest's simple key table for controls.js (keyboard + mouse + controller,
# pause menu, rebinding) and tightens the player's input handling.
# build_play.py runs this last, after the story, content and audio passes.
import sys

def _controls_build():
    path = 'tenebrae-play.html'
    page = open(path).read()
    if 'const CTRL = ' in page:
        sys.exit('build_controls: already applied; run build_play.py for a fresh build')

    def rep(a, b, n=1):
        nonlocal page
        c = page.count(a)
        if c != n:
            sys.exit(f'build_controls: COUNT {c} for: {a[:90]}')
        page = page.replace(a, b)

    # --- the input layer itself
    s = page.index('/* ---------- input: keyboard + gamepad ---------- */')
    e = page.index('\n}\n', page.index('function pollInput()', s)) + 3
    page = page[:s] + open('controls.js').read() + page[e:]

    # --- the loop polls input once, then the pause menu decides whether the arena runs
    rep("function arenaSim(ctx, rdt, r) {\n  pollInput();\n", "function arenaSim(ctx, rdt, r) {\n")
    rep("mount('cv-demo', DW, DH, (ctx, t, dt, r) => arenaSim(ctx, dt, r),",
        "mount('cv-demo', DW, DH, (ctx, t, dt, r) => { window.WB = r.st; window.WBC = CTRL; pollInput(); const go = CTRL.step(r.st, dt); arenaSim(ctx, go ? dt : 0, r); CTRL.draw(ctx, r.W, r.H); },")
    # reduced-motion visitors still need a running game here (the pitch page freezes its plates instead)
    rep("if (reduce) {\n  R.forEach(r => { r.t = .55; draw(r, 0); });", "if (false) {\n  R.forEach(r => { r.t = .55; draw(r, 0); });")

    # --- choices: arrows pick, Enter / Space / attack confirm, 1-3 pick and confirm, dash or Backspace leaves the shop
    rep("""      if (PR.jump || PR.attack) { o.at = o.t; o.dur = o.t + .9; }
      else if (PR.dash && o.kind === 'shop') { o.pick = -1; o.at = o.t; o.dur = o.t + .9; }
    } else if (o.kind === 'over' && o.t > 2.5 && (PR.jump || PR.attack)) o.dur = o.t;""",
        """      if (PR.up) o.pick = (o.pick + n - 1) % n;
      if (PR.down) o.pick = (o.pick + 1) % n;
      if (PR.pick >= 0 && PR.pick < n) { o.pick = PR.pick; o.at = o.t; o.dur = o.t + .9; }
      else if (PR.ok) { o.at = o.t; o.dur = o.t + .9; }
      else if ((PR.dash || PR.back) && o.kind === 'shop') { o.pick = -1; o.at = o.t; o.dur = o.t + .9; }
    } else if (o.kind === 'over' && o.t > 2.5 && PR.ok) o.dur = o.t;""")
    rep("txt(o.kind === 'shop' ? '← →  CHOOSE     J / SPACE  BUY     SHIFT  LEAVE' : '← →  CHOOSE     J / SPACE  CONFIRM'",
        "txt(o.kind === 'shop' ? `← →  CHOOSE     ENTER / ${keyLabel('attack')}  BUY     ${keyLabel('dash')}  LEAVE` : `← →  CHOOSE     1-${o.opts.length} / ENTER / ${keyLabel('attack')}  CONFIRM`")
    rep("txt(t > 2.5 ? 'PRESS J OR SPACE TO RELIGHT THE CANDLES · NEW SEED · NEW DRAWS' : 'LIGHTS OUT'",
        "txt(t > 2.5 ? `PRESS ENTER OR ${keyLabel('attack')} TO RELIGHT THE CANDLES · NEW SEED · NEW DRAWS` : 'LIGHTS OUT'")

    # --- buffers: a jump, swing or dash pressed during a dash, slam or hit-stop fires as soon as it can
    rep("    if (st.dying) { p.vx *= Math.max(0, 1 - dt * 6);",
        """    for (const [k, b] of [['jump', 'buf'], ['attack', 'abuf'], ['dash', 'dbuf']]) {
      if (PR[k]) p[b] = k === 'attack' ? .16 : .14; else if (!(p.dash > 0)) p[b] = Math.max(0, (p[b] || 0) - dt);
    }
    if (PR.attack) p.mouseAtk = MOUSE.aim;
    if (PR.dash) p.mouseDash = MOUSE.aim;
    if (st.dying) { p.vx *= Math.max(0, 1 - dt * 6);""")
    rep("""      dir = (IN.right ? 1 : 0) - (IN.left ? 1 : 0);""", """      dir = IN.dir;""")
    rep("""      p.buf = PR.jump ? .12 : Math.max(0, (p.buf || 0) - dt);
      if (PR.dash && p.dashCd <= 0 && !(p.airDash && !p.ground)) {
        if (dir) p.f = dir;""", """      if (p.dbuf > 0 && p.dashCd <= 0 && !(p.airDash && !p.ground)) {
        const ms = p.mouseDash && !dir ? mouseSide(st, p.x, W) : 0; p.dbuf = 0;
        if (dir) p.f = dir; else if (ms) p.f = ms;""")
    rep("""      if (PR.attack) {
        if (!p.ground && IN.down) { p.slam = true; p.atk = null; }
        else if (!p.atk) { p.atk = { step: 0, t: 0, hit: false, q: false }; if (dir) p.f = dir; }
        else p.atk.q = true;
      }""", """      // tap to swing, hold to keep the combo going; down + attack in the air slams
      if (p.abuf > 0 && !p.ground && IN.down) { p.abuf = 0; p.slam = true; p.atk = null; }
      else if (!p.atk && (p.abuf > 0 || IN.attack)) {
        const ms = p.mouseAtk ? mouseSide(st, p.x, W) : 0; p.abuf = 0;
        p.atk = { step: 0, t: 0, hit: false, q: false }; if (ms) p.f = ms; else if (dir) p.f = dir;
      } else if (p.atk && p.abuf > 0) { p.abuf = 0; p.atk.q = true; }
      if (p.atk && IN.attack) p.atk.q = true;""")
    # snappier running: constant acceleration like the Godot build instead of an easing lerp
    rep("p.vx = lerp(p.vx, dir * sp, Math.min(1, dt * (p.ground ? 12 : 6)));",
        "const tv = dir * sp, acc = p.ground ? (Math.abs(tv) < Math.abs(p.vx) ? 4200 : 3600) : 2400; p.vx += clamp(tv - p.vx, -acc * dt, acc * dt);")

    # --- the HUD and the page show the keys you actually have
    rep("ctx.fillText('J / CLICK  NEXT     ESC  SKIP', W - 16, 22)", "ctx.fillText(`${keyLabel('attack')} / CLICK  NEXT     ESC  SKIP`, W - 16, 22)")
    rep("[['DASH', 'SHIFT', Math.max(0, p.dashCd) / .6], ['SLAM', 'S+J', 0], ['WALL', 'SPACE', 0]]",
        "[['DASH', keyLabel('dash'), Math.max(0, p.dashCd) / .6], ['SLAM', keyLabel('down') + '+' + keyLabel('attack'), 0], ['WALL', keyLabel('jump'), 0]]")
    rep("sub: 'PRESS Q OR Y', t: 1, col: C.gold }", "sub: `PRESS ${keyLabel('skill')} OR Y`, t: 1, col: C.gold }")
    rep("SKILL_NAMES[st.weapon] + '  ·  Q'", "SKILL_NAMES[st.weapon] + '  ·  ' + keyLabel('skill')")
    s = page.index('<div class="keys">')
    e = page.index('</div>', s) + 6
    page = page[:s] + '<div class="keys" id="keys"></div>' + page[e:]

    open(path, 'w').write(page)
    print('controls ok', len(page))

_controls_build()
