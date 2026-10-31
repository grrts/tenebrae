# Adds the story layer (story.js: chapters, cutscenes, souls-like death) to tenebrae-play.html.
# build_play.py runs this at its end; it can also be run alone inside web/ on a fresh build.
import sys

def _story_build():
    path = 'tenebrae-play.html'
    page = open(path).read()
    if 'const STORY = ' in page:
        sys.exit('build_story: tenebrae-play.html already has the story layer; run build_play.py for a fresh build')
    story = open('story.js').read()

    def rep(a, b, n=1):
        nonlocal page
        c = page.count(a)
        if c != n:
            sys.exit(f'build_story: COUNT {c} for: {a[:90]}')
        page = page.replace(a, b)

    # fonts for title cards, subtitles and the death screen
    rep('family=IBM+Plex+Mono:wght@500;600&display=swap',
        'family=IBM+Plex+Mono:wght@500;600&family=Cinzel:wght@600;800&family=Cormorant+Garamond:ital,wght@0,500;1,500&display=swap')
    # the story module lives in the game scope, before the playtest canvas is mounted
    rep("mount('cv-demo', DW, DH,", story + "\nmount('cv-demo', DW, DH,")
    # cutscenes take over the frame while they play
    rep("  const st = r.st, W = r.W, H = r.H, p = st.p;\n  if (st.ov) {",
        "  const st = r.st, W = r.W, H = r.H, p = st.p;\n  if (STORY.tick(ctx, st, rdt, W, H)) return;\n  if (st.ov) {")
    # run start: prologue or chapter jump
    rep("  st.ov = interactive({ kind: 'weapon', t: 0, at: 1.9, dur: 2.8, opts: [a, b], pick: st.meta.u > 0 && b === 'sickle' ? 1 : a === 'sickle' ? 0 : st.rng() < .5 ? 0 : 1 });\n}",
        "  st.ov = interactive({ kind: 'weapon', t: 0, at: 1.9, dur: 2.8, opts: [a, b], pick: st.meta.u > 0 && b === 'sickle' ? 1 : a === 'sickle' ? 0 : st.rng() < .5 ? 0 : 1 });\n  STORY.onRun(st);\n}")
    rep("FIFTEEN CANDLES · NO END", "FIFTEEN CANDLES · ONE THRONE BELOW")
    # depth, bosses
    rep("        st.dp = 0; st.depth++;\n", "        st.dp = 0; st.depth++; STORY.onDepth(st);\n")
    rep("st.bossName = st.bosses % 2 ? 'THE HOLLOW KING' : 'THE CHAIN WARDEN';", "st.bossName = STORY.bossIntro(st);")
    rep("ai: 'walk', at: 1.6, plat: null, burnT: 0, landed: 0 };\n  st.E.push(st.boss);",
        "ai: 'walk', at: 1.6, plat: null, burnT: 0, landed: 0 };\n  STORY.onBossSpawn(st);\n  st.E.push(st.boss);")
    rep("      st.pendShop = 2.4;\n    }", "      st.pendShop = 2.4; STORY.onBossSlain(st);\n    }")
    rep("e.king ? { headExtra: crownHead } : {}", "STORY.bossLook(e)")
    # hidden candle revive gets a short impact cut
    rep("t: 2, col: C.gold };\n      for (const e of live)", "t: 2, col: C.gold }; STORY.onRevive(st);\n      for (const e of live)")
    # candles: fifteen go out over fifteen depths and stay out, darkness is total at the throne
    rep("const out = (depth - 1) % 15, w = 150, top = 46;", "const out = STORY.candlesOut(depth), w = 150, top = 46;")
    rep("const out = (st.depth - 1) % 15 + Math.floor((st.depth - 1) / 15) * 3, k = clamp(out / 11, 0, 1);",
        "const out = STORY.candlesOut(st.depth), k = clamp(out / 11, 0, 1) * (st.depth >= 16 ? 1.06 : 1);")
    rep("· SEED ${seedHex(st.seed)} · HANGING SPIRE`", "· SEED ${seedHex(st.seed)} · ${STORY.place(st)}`")
    # souls-like death: stagger, kneel on the blade, crumble to ash, EXTINGUISHED
    rep("if (st.hp <= 0) { st.hp = 0; st.dying = 1.8;", "if (st.hp <= 0) { st.hp = 0; st.dying = STORY.DEATH_T; st.hitstop = .3; st.shake = .45;")
    rep("if (st.dying) { pose = { lean: .5, tilt: .4, legs: [[-.15, -1.55], [.95, -1.45]], arms: [[.2, .3], [.5, .2]] }; hip = y - 25; bladeAng = f > 0 ? .15 : PI - .15; }",
        "if (st.dying) { ({ pose, hip, bladeAng } = STORY.deathPose(st, p)); }")
    rep("ctx.globalAlpha = st.dying ? clamp(st.dying / 1.8, 0, 1) :", "ctx.globalAlpha = st.dying ? STORY.deathAlpha(st) :")
    rep("if (st.dying) { ctx.fillStyle = `rgba(0,0,0,${(1 - st.dying / 1.8) * .5})`; ctx.fillRect(0, 0, W, H); }", "if (st.dying) STORY.deathDim(ctx, st, W, H);")
    rep("  if (st.ov) (st.ov.kind === 'over' ? drawSummary : drawChoice)(ctx, st, W, H, txt);\n}",
        "  if (st.ov) (st.ov.kind === 'over' ? drawSummary : drawChoice)(ctx, st, W, H, txt);\n  if (st.dying) STORY.drawDeath(ctx, st, W, H);\n}")
    # victory summary after the finale
    rep("st.ov = { kind: 'over', t: 0, dur: 30,", "st.ov = { kind: 'over', t: 0, dur: 30, victory: !!st.victory,")
    rep("txt('LIGHTS OUT', W / 2, 100, `900 64px ${DISP}`, C.crimson, 'center', 6);",
        "txt(o.victory ? 'THE DAWN RETURNS' : 'LIGHTS OUT', W / 2, 100, `900 64px ${DISP}`, o.victory ? C.gold : C.crimson, 'center', 6);")
    rep('<div class="keys">', '<div class="keys"><b>ESC</b> skip cutscene · <b>J</b> next shot · ')
    open(path, 'w').write(page)
    print('story ok', len(page))

_story_build()
