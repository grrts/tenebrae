# Adds meta-progression (meta.js) to tenebrae-play.html: banked ash is saved per browser and
# spent in the Reliquary between runs on Blessings (permanent stat ranks) and Relics (unlocks);
# beating a chapter boss lights a Waystone so later runs can start at that chapter.
# build_play.py runs this last, after the controls pass.
import sys

def _meta_build():
    path = 'tenebrae-play.html'
    page = open(path).read()
    if 'const META = ' in page:
        sys.exit('build_meta: already applied; run build_play.py for a fresh build')

    def rep(a, b, n=1):
        nonlocal page
        c = page.count(a)
        if c != n:
            sys.exit(f'build_meta: COUNT {c} for: {a[:90]}')
        page = page.replace(a, b)

    rep("mount('cv-demo', DW, DH,", open('meta.js').read() + "\nmount('cv-demo', DW, DH,")
    # the saved meta replaces the pitch page's demo numbers
    rep("meta: { u: 0, have: 290, best: 6, well: false }", "meta: META.load()")

    # --- a run starts with everything bought applied
    rep("""  const pool = WEAPONS.filter(w => w !== 'sickle' || st.meta.u > 0);
  const a = pool[Math.floor(st.rng() * pool.length)]; let b; do b = pool[Math.floor(st.rng() * pool.length)]; while (b === a);
  st.ov = interactive({ kind: 'weapon', t: 0, at: 1.9, dur: 2.8, opts: [a, b], pick: st.meta.u > 0 && b === 'sickle' ? 1 : a === 'sickle' ? 0 : st.rng() < .5 ? 0 : 1 });
  STORY.onRun(st);""", """  const pool = WEAPONS.filter(w => w !== 'sickle' || st.meta.own.sickle);
  st.ov = interactive({ kind: 'weapon', t: 0, at: 1.9, dur: 2.8, opts: META.weaponDraw(st, pool), pick: 0 });
  STORY.onRun(st); META.begin(st);""")
    rep("(n !== 'IRON VEIL' || st.meta.u > 1)", "(n !== 'IRON VEIL' || st.meta.own.veil)")
    rep("st.weapon = v; st.banner = { text: 'DESCEND', sub: `${v.toUpperCase()} · DEPTH I · FIFTEEN CANDLES · ONE THRONE BELOW`, t: 1.7 };",
        "st.weapon = v; if (st.freeDrafts > 0) st.pendDraft = .6; st.banner = { text: 'DESCEND', sub: `${v.toUpperCase()} · DEPTH ${roman(st.depth)} · ${16 - st.depth} CANDLES · ONE THRONE BELOW`, t: 1.7 };")
    rep("    st.runes.push(v);\n", "    st.runes.push(v); if (st.freeDrafts > 0 && --st.freeDrafts > 0) st.pendDraft = .35;\n")
    rep("if (st.runes[i] === 'GLASS EDGE') st.maxHp = 5;", "if (st.runes[i] === 'GLASS EDGE') st.maxHp = st.baseHp;")
    rep("if (st.maxHp < 5) txt('CURSED'", "if (st.maxHp < st.baseHp) txt('CURSED'")

    # --- the run ends: bank the ash, then the Reliquary, then a new run
    s = page.index('function openOver(st) {')
    e = page.index('function applyPick(st) {')
    page = page[:s] + 'function openOver(st) { META.over(st); }\n' + page[e:]
    rep("if (o.t >= o.dur) { st.ov = null; if (o.kind === 'over') newRun(st); }",
        "if (o.t >= o.dur) { st.ov = null; if (o.kind === 'over') META.open(st); }")
    rep("  if (st.ov) {\n    const o = st.ov; o.t += rdt;", "  if (st.ov && st.ov.kind === 'relic') META.step(st, rdt);\n  else if (st.ov) {\n    const o = st.ov; o.t += rdt;")
    # the weapon draw can step back into the Reliquary
    rep("      else if ((PR.dash || PR.back) && o.kind === 'shop') {", "      else if ((PR.dash || PR.back) && o.kind === 'weapon') META.open(st, true);\n      else if ((PR.dash || PR.back) && o.kind === 'shop') {")
    rep(": `← →  CHOOSE     1-${o.opts.length} / ENTER / ${keyLabel('attack')}  CONFIRM`",
        ": `← →  CHOOSE     1-${o.opts.length} / ENTER / ${keyLabel('attack')}  CONFIRM${o.kind === 'weapon' ? `     ${keyLabel('dash')}  RELIQUARY · ◆ ${st.meta.ash}` : ''}`")
    rep("if (st.ov) (st.ov.kind === 'over' ? drawSummary : drawChoice)(ctx, st, W, H, txt);",
        "if (st.ov) (st.ov.kind === 'relic' ? META.draw : st.ov.kind === 'over' ? drawSummary : drawChoice)(ctx, st, W, H, txt);")
    s = page.index('  // ash\n  const ki = clamp((t - 1.2) / .8, 0, 1);')
    e = page.index("  txt(t > 2.5 ? `PRESS ENTER OR ${keyLabel('attack')} TO RELIGHT THE CANDLES")
    page = page[:s] + '  META.summary(ctx, st, W, H, txt, t);\n' + page[e:]
    rep("`PRESS ENTER OR ${keyLabel('attack')} TO RELIGHT THE CANDLES · NEW SEED · NEW DRAWS`",
        "`PRESS ENTER OR ${keyLabel('attack')} TO SPEND YOUR ASH IN THE RELIQUARY`")

    # --- blessings in play
    rep("dmg = dmg * (glass ? 2 : 1) + st.temper + (crit && has(st, 'WHETSTONE') ? 1 : 0);",
        "dmg = (dmg * (glass ? 2 : 1) + st.temper + (crit && has(st, 'WHETSTONE') ? 1 : 0)) * st.mods.dmg;")
    rep("const sp = p.atk ? 80 : 310;", "const sp = (p.atk ? 80 : 310) * st.mods.spd;")
    rep("p.dashCd = has(st, 'GALE STEP') ? .45 : .6; st.dashId++;", "p.dashCd = (has(st, 'GALE STEP') ? .45 : .6) * st.mods.dash; st.dashId++;")
    rep("st.runWax += has(st, 'HUNGER') ? 3 : 2; st.xp++;", "st.runWax += META.ash(st, has(st, 'HUNGER') ? 3 : 2); st.xp++;")
    rep("const need = 8 + st.lvl * 5", "const need = Math.max(4, Math.round((8 + st.lvl * 5) * st.mods.xp))", 2)
    rep("    e.dead = true; st.kills++;\n", "    e.dead = true; st.kills++; META.onKill(st, e);\n")
    # the spare candle: the hidden candle comes back one more time
    rep("st.hidden = false; st.hp = Math.ceil(st.maxHp / 2);", "st.hidden = st.spare-- > 0; st.hp = Math.ceil(st.maxHp / 2);")
    rep("sub: 'RETURNED ONCE · IT WILL NOT RETURN AGAIN'", "sub: st.hidden ? 'THE SPARE CANDLE STILL BURNS · ONE MORE RETURN' : 'RETURNED ONCE · IT WILL NOT RETURN AGAIN'")
    open(path, 'w').write(page)
    print('meta ok', len(page))

_meta_build()
