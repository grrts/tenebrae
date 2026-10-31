# Adds the enemy brains (ai.js) to tenebrae-play.html: climbing, lunges, dodges,
# flanking, leading shots, gloomwing dives and a move set per boss.
# build_play.py runs this after build_content.py.
import sys

def _ai_build():
    path = 'tenebrae-play.html'
    page = open(path).read()
    if 'const AI = ' in page:
        sys.exit('build_ai: already applied; run build_play.py for a fresh build')

    def rep(a, b, n=1):
        nonlocal page
        c = page.count(a)
        if c != n:
            sys.exit(f'build_ai: COUNT {c} for: {a[:90]}')
        page = page.replace(a, b)

    rep("mount('cv-demo', DW, DH,", open('ai.js').read() + "\nmount('cv-demo', DW, DH,")
    # bosses: the whole branch is replaced by AI.boss
    a = page.index("        const dx = p.x - e.x; e.at -= dt;\n        if (e.ground && !e.landed)")
    b = page.index("        e.vy += GRV * dt; arenaMove(e, dt, e.w, e.h, true);")
    page = page[:a] + "        AI.boss(st, e, p, dt, sm, hitPlayer);\n" + page[b:]
    rep("const wind = e.ai === 'wind' ? 1 - e.at / .75 : 0;", "const wind = e.ai === 'wind' ? clamp(1 - e.at / (e.windT || .75), 0, 1) : e.ai === 'dash' ? 1 : 0;")
    # gloomwings
    rep("      } else if (e.type === 'bat') {\n        const tx = p.x + S(st.time + e.o) * 60,",
        "      } else if (e.type === 'bat') {\n        if (AI.bat(st, e, p, dt, sm, () => hitPlayer(dmgN))) continue;\n        const tx = p.x + AI.batX(st, e, p) + S(st.time + e.o) * 30,")
    # ground enemies: the brain gets the first say each frame
    rep("        if (e.ground && Math.abs(e.vx) < 100) {\n          if (CONTENT.ai(",
        "        if (AI.ground(st, e, p, dx, dy, dt, sm, () => hitPlayer(dmgN))) {}\n        else if (e.ground && Math.abs(e.vx) < 100) {\n          if (CONTENT.ai(")
    rep("arenaMove(e, dt, e.w, e.h, false);", "arenaMove(e, dt, e.w, e.h, e.dropT > 0);")
    # the forged's throws now come from the brain (aimed, and doubled deeper down)
    rep("    if (e.type === 'fg') {\n      e.act", "    if (e.type === 'fg' && false) {\n      e.act")
    # drowned pounce at where you're going
    rep("e.vx = clamp(dx * 1.6, -560, 560); e.vy = -640;", "e.vx = clamp((dx + clamp(p.vx * .35, -140, 140)) * 1.6, -600, 600); e.vy = -640;")
    # snuffers blink in a little faster deeper down
    rep("e.act = .5; e.cd = rnd(2.6, 3.6);", "e.act = st.depth >= 15 ? .42 : .5; e.cd = rnd(2.2, 3.2);")
    # danger markers, drawn over the enemies
    rep("  for (const q of st.proj) { if (q.blade) {", "  AI.draw(ctx, st);\n  for (const q of st.proj) { if (q.blade) {")
    open(path, 'w').write(page)
    print('ai ok', len(page))

_ai_build()
