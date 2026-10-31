# Adds the Godot build's weapon skills to tenebrae-play.html: landing hits fills a
# meter, and Q (or Y on a pad) fires the equipped weapon's skill.
# build_play.py runs this after the other sub-builds.
import sys

def _skills_build():
    path = 'tenebrae-play.html'
    page = open(path).read()
    if 'const SKILL_NAMES' in page:
        sys.exit('build_skills: already applied; run build_play.py for a fresh build')

    def rep(a, b, n=1):
        nonlocal page
        c = page.count(a)
        if c != n:
            sys.exit(f'build_skills: COUNT {c} for: {a[:90]}')
        page = page.replace(a, b)

    # input: Q / Y
    rep("dash: ['ShiftLeft', 'ShiftRight', 'KeyL', 'KeyC'] };", "dash: ['ShiftLeft', 'ShiftRight', 'KeyL', 'KeyC'], skill: ['KeyQ'] };")
    rep("jump: b(0), attack: b(2), dash: b(5) || b(7) || b(1) };", "jump: b(0), attack: b(2), dash: b(5) || b(7) || b(1), skill: b(3) };")
    rep("function arenaSim(ctx, rdt, r) {\n", """const SKILL_NAMES = { katana: 'IAIDO', greatsword: 'EARTHSPLITTER', spear: 'SKYWARD', daggers: 'FLURRY', sickle: 'REAP' };
const SKILL_DESC = { katana: 'FLASH THROUGH EVERYTHING AHEAD', greatsword: 'SPLIT THE FLOOR BOTH WAYS', spear: 'LAUNCH UP THROUGH EVERYTHING ABOVE', daggers: 'EIGHT CUTS ON EVERYTHING CLOSE', sickle: 'DRAG EVERY ENEMY NEARBY TO YOU' };
function arenaSim(ctx, rdt, r) {
""")
    rep("weapon: 'katana' });", "weapon: 'katana', skill: 0 });")
    # hits charge the meter (skill hits do not)
    rep("    e.hp -= dmg; e.hit = .12;\n", """    e.hp -= dmg; e.hit = .12;
    if (!st.skilling) { const was = st.skill >= 1; st.skill = Math.min(1, (st.skill || 0) + (e.type === 'boss' ? .05 : .07));
      if (!was && st.skill >= 1) st.banner = { text: SKILL_NAMES[st.weapon] + ' READY', sub: 'PRESS Q OR Y', t: 1, col: C.gold }; }
""")
    # firing
    rep("      if (p.ground || p.vy >= 0) p.cut = false;\n", """      if (p.ground || p.vy >= 0) p.cut = false;
      if (PR.skill && st.skill >= 1) {
        st.skill = 0; st.skilling = true; st.shake = .3; st.hitstop = .12;
        const w = st.weapon, py = p.y - 28;
        st.banner = { text: SKILL_NAMES[w], sub: SKILL_DESC[w], t: 1, col: C.gold };
        st.rings.push({ x: p.x, y: py, t: 0, kind: 'gale' });
        for (const e of live) {
          const dx = e.x - p.x, dy = (e.y - e.h / 2) - py;
          if (w === 'katana' && dx * p.f > -20 && dx * p.f < 320 && Math.abs(dy) < 70) hurt(e, 3, p.f * 300, -300, true);
          else if (w === 'greatsword' && Math.abs(dx) < 420 && Math.abs(dy) < 60) hurt(e, 3, Math.sign(dx || 1) * 260, -700, true);
          else if (w === 'spear' && Math.abs(dx) < 90 && dy < 30 && dy > -420) hurt(e, 3, 0, -900, true);
          else if (w === 'daggers' && Math.hypot(dx, dy) < 170) for (let i = 0; i < 4; i++) hurt(e, 1, p.f * 60, -120, i === 3);
          else if (w === 'sickle' && Math.hypot(dx, dy) < 320) { if (e.type !== 'boss') { e.x = p.x + p.f * 34; e.y = p.y; } hurt(e, 3, p.f * 120, -300, true); }
        }
        if (w === 'katana') { p.dash = .22; p.dashCd = 0; st.dashId++; p.vx = p.f * 1300; }
        if (w === 'spear') { p.vy = -1250; p.ground = false; p.flip = .4; }
        if (w === 'greatsword') { st.rings.push({ x: p.x - 200, y: p.y, t: 0, kind: 'gale' }, { x: p.x + 200, y: p.y, t: 0, kind: 'gale' }); }
        st.skilling = false;
      }
""")
    # meter under the health bar
    rep("    if (st.maxHp < 5) txt('CURSED',", """    { const sk = clamp(st.skill || 0, 0, 1); ctx.save(); ctx.fillStyle = 'rgba(0,0,0,.75)'; ctx.fillRect(bx - 2, by + 20, bw + 4, 8);
      ctx.fillStyle = sk >= 1 ? C.gold : 'rgba(242,180,58,.6)'; if (sk >= 1) { ctx.shadowColor = C.gold; ctx.shadowBlur = 8 + S(st.time * 8) * 4; }
      ctx.fillRect(bx, by + 22, bw * sk, 4); ctx.restore();
      txt(sk >= 1 ? SKILL_NAMES[st.weapon] + '  ·  Q' : SKILL_NAMES[st.weapon], bx + bw + 10, by + 29, `600 10px ${MONO}`, sk >= 1 ? C.gold : '#9a9289', 'left', 3); }
    if (st.maxHp < 5) txt('CURSED',""")
    rep("<b>SHIFT</b> dash ·", "<b>SHIFT</b> dash · <b>Q</b> weapon skill when the meter is full ·")
    open(path, 'w').write(page)
    print('skills ok', len(page))

_skills_build()
