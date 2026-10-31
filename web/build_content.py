# Adds the Godot prototype's newer content (content.js: the dungeon enemies) to tenebrae-play.html.
# build_play.py runs this after build_story.py.
import sys

def _content_build():
    path = 'tenebrae-play.html'
    page = open(path).read()
    if 'const CONTENT = ' in page:
        sys.exit('build_content: already applied; run build_play.py for a fresh build')

    def rep(a, b, n=1):
        nonlocal page
        c = page.count(a)
        if c != n:
            sys.exit(f'build_content: COUNT {c} for: {a[:90]}')
        page = page.replace(a, b)

    rep("mount('cv-demo', DW, DH,", open('content.js').read() + "\nmount('cv-demo', DW, DH,")
    # each lower dungeon brings its own enemy
    rep("const type = d >= 3 && q < .14 ? 'sp' : d >= 2 && q < .34 ? 'bat' : d >= 5 && q < .48 ? 'br' : 'sh';",
        "const ch = Math.min(3, Math.floor((d - 1) / 4)), type = ch > 0 && q < .22 ? ['', 'dr', 'fg', 'sn'][ch] : d >= 3 && q < .34 ? 'sp' : d >= 2 && q < .52 ? 'bat' : d >= 5 && q < .64 ? 'br' : 'sh';")
    rep("const hp = { sh: 3, bat: 1, br: 9, sp: 2 }[type]", "const hp = { sh: 3, bat: 1, br: 9, sp: 2, dr: 4, fg: 4, sn: 3 }[type]")
    rep("          if (e.type === 'sp') { e.vx = 0;", "          if (CONTENT.ai(st, e, p, dx, dy, dt, sm, () => hitPlayer(dmgN))) {}\n          else if (e.type === 'sp') { e.vx = 0;")
    rep("      const reach = e.type === 'boss' ? 34 : 20;",
        "      if (e.pounce > 0) { e.pounce -= dt; if (p.hurt <= 0 && p.dash <= 0 && Math.abs(e.x - p.x) < 26 && Math.abs((e.y - e.h / 2) - (p.y - 28)) < 40) { e.pounce = 0; hitPlayer(dmgN); } }\n      const reach = e.type === 'boss' ? 34 : 20;")
    rep("    for (const q of st.proj) { q.vy += 900 * dt;", "    for (const q of st.proj) { if (!q.blade) q.vy += 900 * dt;")
    rep("    else drawHexer(ctx, e.x, e.y, .7 * e.sc, st.time + e.o, e.f, look);",
        "    else if (e.type === 'sp') drawHexer(ctx, e.x, e.y, .7 * e.sc, st.time + e.o, e.f, look);\n    else CONTENT.draw(ctx, e, st, tt, look);")
    rep("  for (const q of st.proj) { ctx.save(); ctx.fillStyle = C.violet;", "  for (const q of st.proj) { if (q.blade) { CONTENT.drawBlade(ctx, q, st); continue; } ctx.save(); ctx.fillStyle = C.violet;")
    open(path, 'w').write(page)
    print('content ok', len(page))

_content_build()
