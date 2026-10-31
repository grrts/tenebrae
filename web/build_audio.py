# Adds the sound layer (audio.js: procedural SFX, dark ambient score, gibberish voices) to tenebrae-play.html.
# build_play.py runs this at its end, after build_story.py; it can also be run alone inside web/ on a story build.
import sys

def _audio_build():
    path = 'tenebrae-play.html'
    page = open(path).read()
    if 'const AUDIO = ' in page:
        sys.exit('build_audio: tenebrae-play.html already has the sound layer; run build_play.py for a fresh build')
    if 'const STORY = ' not in page:
        sys.exit('build_audio: run build_story.py first')
    audio = open('audio.js').read()

    def rep(a, b, n=1):
        nonlocal page
        c = page.count(a)
        if c != n:
            sys.exit(f'build_audio: COUNT {c} for: {a[:90]}')
        page = page.replace(a, b)

    # the module sits right after the story module, in the same scope
    rep("\nmount('cv-demo', DW, DH,", "\n" + audio + "\nmount('cv-demo', DW, DH,")
    # cutscene shots are read by the audio layer for its cues and voices
    rep("deathPose, deathAlpha, deathDim, drawDeath, chOf };", "deathPose, deathAlpha, deathDim, drawDeath, chOf, SC };")
    # one watcher call per frame, before a cutscene can take the frame
    rep("  if (STORY.tick(ctx, st, rdt, W, H)) return;", "  AUDIO.watch(st, rdt);\n  if (STORY.tick(ctx, st, rdt, W, H)) { AUDIO.hud(ctx, W, H); return; }")
    rep("  if (st.dying) STORY.drawDeath(ctx, st, W, H);\n}", "  if (st.dying) STORY.drawDeath(ctx, st, W, H);\n  AUDIO.hud(ctx, W, H);\n}")
    rep('<div class="keys">', '<div class="keys"><b>M</b> sound on/off · ')
    open(path, 'w').write(page)
    print('audio ok', len(page))

_audio_build()
