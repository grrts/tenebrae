// Enemy brains (mirrors src/enemy.gd and src/boss.gd in the Godot build).
// Regular enemies share a few habits: they climb to your platform and drop down
// to you, hollows lunge, brutes swing and charge, hexers lead their shots and
// back off when you close in, gloomwings circle behind you and dive at where
// you are going, and a crowded side sends one enemy vaulting over you so you
// end up surrounded. They also sidestep your swings, more often the deeper you go.
// A few attack tokens keep the pressure high without everyone striking at once.
// Every attack has a wind-up that is drawn as a danger marker, so it stays fair.
const AI = (() => {
  const L = st => clamp((st.depth - 1) / 12, 0, 1);               // 0 at depth I, 1 by depth XIII
  const floorAt = (x, y) => { const c = Math.floor(x / TS), r = Math.floor((y + 2) / TS); return isSolid(DA, c, r) || isOne(DA, c, r); };
  const wallAt = (x, y) => isSolid(DA, Math.floor(x / TS), Math.floor(y / TS));
  // the player's body, feet at p.y
  const body = (p, x0, x1, y0, y1) => p.x + 9 > Math.min(x0, x1) && p.x - 9 < Math.max(x0, x1) && p.y > y0 && p.y - 56 < y1;
  const tokens = st => 2 + Math.floor(st.depth / 5);
  function busy(st) { let n = 0; for (const e of st.E) if (!e.dead && e.type !== 'boss' && (e.mode === 'wind' || e.mode === 'lunge' || e.mode === 'swing' || e.mode === 'charge' || e.mode === 'cwind')) n++; return n; }
  function sideCount(st, p, s) { let n = 0; for (const o of st.E) if (!o.dead && o.type !== 'bat' && o.type !== 'boss' && Math.sign(o.x - p.x) === s && Math.abs(o.x - p.x) < 260 && Math.abs(o.y - p.y) < 50) n++; return n; }

  // clear headroom between the feet and a target height, so a jump is not wasted on a ceiling
  function headroom(e, toY, dir) {
    const c = Math.floor((e.x + dir * TS * .4) / TS);
    for (let r = Math.floor((e.y - e.h - 4) / TS); r >= Math.floor((toY - e.h) / TS); r--) if (isSolid(DA, c, r)) return false;
    return true;
  }

  // ground enemies; true when the brain drove this frame
  function ground(st, e, p, dx, dy, dt, sm, hit) {
    const l = L(st), adx = Math.abs(dx), s = Math.sign(e.x - p.x) || 1;
    e.aiCd = (e.aiCd ?? rnd(.6, 1.6)) - dt * Math.sqrt(sm); e.dodgeCd = (e.dodgeCd ?? 0) - dt; e.jumpCd = (e.jumpCd ?? 0) - dt; e.dropT = Math.max(0, (e.dropT || 0) - dt);
    if (e.hit > 0 && e.type !== 'br') { if (e.mode && e.mode !== 'vault') e.mode = null; e.tele = 0; return false; }   // a hit staggers them
    if (e.mode) return act(st, e, p, dx, dy, dt, sm, hit, l);
    if (e.type === 'sp') return hexer(st, e, p, dx, dy, dt, sm, l);
    // snuffers at the Throne feint: if you turn to face the blink, they blink again to your back
    if (e.type === 'sn' && e.act > .2 && !e.feint && st.depth >= 13 && Math.sign(e.x - p.x) === p.f && Math.random() < dt * 6) {
      const tx = p.x - p.f * 70; e.feint = 1;
      if (floorAt(tx, p.y) && !wallAt(tx, p.y - 20)) { sparks(st.P, e.x, e.y - 28, 1, 10, C.violet); e.x = tx; e.y = p.y; e.vy = 0; e.f = -p.f; e.act = .45; sparks(st.P, e.x, e.y - 28, 1, 10, C.violet); }
    }
    if (e.type === 'sn' && !(e.act > 0)) e.feint = 0;
    if (!e.ground || e.act > 0) return false;                                // in the air, or the dungeon brain is mid-move

    // sidestep the player's swing: read it in the first moments of the attack
    if (p.atk && p.atk.t < .09 && e.dodgeCd <= 0 && (e.x - p.x) * p.f > -10 && adx < REACH[st.weapon] + 60 && Math.abs(dy) < 60 && e.type !== 'br') {
      e.dodgeCd = 1.4;
      if (Math.random() < .14 + l * .36 + (e.elite === 'SWIFT' ? .2 : 0) && floorAt(e.x + s * 60, e.y)) {
        e.vx = s * 430; e.vy = -430; e.ground = false; e.mode = 'hop'; e.mt = .5; e.aiCd = Math.min(e.aiCd, .25);  // and punish the recovery
        return true;
      }
    }
    // climb to the player's platform, or drop down to them
    if (e.type !== 'br' && e.type !== 'sn' && e.jumpCd <= 0 && dy < -56 && dy > -270 && adx < 240 && p.ground && headroom(e, p.y, Math.sign(dx))) {
      const H = -dy + 34, vy = -Math.min(1060, Math.sqrt(2 * GRV * H)), t = -vy / GRV;
      e.vy = vy; e.vx = clamp(dx / (t * 1.7), -320, 320); e.ground = false; e.jumpCd = rnd(.9, 1.5); e.f = Math.sign(dx) || 1;
      return true;
    }
    if (dy > 56 && adx < 220 && e.plat === 'one' && e.jumpCd <= 0) { e.dropT = .25; e.ground = false; e.vy = 60; e.jumpCd = .8; return true; }

    if (Math.abs(dy) < 44) {
      // surround: when the player's back is open and this side is crowded, vault over them
      if ((e.type === 'sh' || e.type === 'dr') && st.depth >= 2 && adx < 170 && (st.vaultT ?? 0) < st.time && sideCount(st, p, s) >= 2 && sideCount(st, p, -s) === 0
        && floorAt(p.x - s * 80, p.y) && !wallAt(p.x - s * 80, p.y - 30) && headroom(e, e.y - 140, -s)) {
        st.vaultT = st.time + rnd(2.2, 3.4) - l;
        const T = 2 * 760 / GRV; e.vy = -760; e.vx = clamp((p.x - s * 80 - e.x) / T, -420, 420); e.ground = false; e.mode = 'vault'; e.mt = T + .2; e.f = -s;
        return true;
      }
      if (e.aiCd <= 0 && busy(st) < tokens(st)) {
        if (e.type === 'sh' && adx > 28 && adx < 175) return windup(e, 'lunge', (.36 - .1 * l) / Math.sqrt(sm), dx);
        if (e.type === 'br' && adx < 95) return windup(e, 'swing', .7 / Math.sqrt(sm), dx);
        if (e.type === 'br' && adx > 200 && adx < 560 && st.depth >= 6) return windup(e, 'charge', .65 / Math.sqrt(sm), dx);
        if (e.type === 'fg' && adx < 640) return windup(e, 'throw', .45 / Math.sqrt(sm), dx);
      }
    } else if (e.type === 'fg' && e.aiCd <= 0 && adx < 520 && dy > -260 && dy < 0 && busy(st) < tokens(st)) return windup(e, 'throw', .45 / Math.sqrt(sm), dx); // aim up at a ledge
    // hold a little space instead of piling into the same spot as an ally
    if (e.type === 'sh' && adx < 60 && adx > 26 && e.aiCd > .4) { e.vx = lerp(e.vx, 0, Math.min(1, dt * 6)); return true; }
    return false;
  }

  function windup(e, kind, t, dx) {
    e.mode = 'wind'; e.next = kind; e.tele = e.teleMax = t; e.f = Math.sign(dx) || e.f; e.vx *= .3;
    if (kind === 'throw') e.act = t;      // the forged's glow
    return true;
  }

  function act(st, e, p, dx, dy, dt, sm, hit, l) {
    if (e.mode === 'hop' || e.mode === 'vault') { e.mt -= dt; e.airT = (e.airT || 0) + dt; if (e.mt <= 0 || (e.ground && e.airT > .12)) { e.mode = null; e.airT = 0; } if (e.mode === 'vault' && Math.abs(e.x - p.x) < 20 && body(p, e.x - 12, e.x + 12, e.y - e.h, e.y) && e.vy > 0) hit(); return false; }
    if (e.mode === 'wind') {
      e.tele -= dt; e.vx = lerp(e.vx, 0, Math.min(1, dt * 10));
      // late reads: lunges and throws keep tracking for the first half of the wind-up
      if (e.tele > e.teleMax * .5 && e.next !== 'charge') e.f = Math.sign(dx) || e.f;
      if (e.tele > 0) return true;
      e.tele = 0;
      if (e.next === 'lunge') { const lead = clamp(p.vx * .18 * l, -60, 60); e.vx = clamp((dx + lead) * 3.6, -600, 600) || e.f * 400; e.vy = -230; e.ground = false; e.mode = 'lunge'; e.mt = .42; }
      else if (e.next === 'swing') { e.mode = 'swing'; e.mt = .35;
        st.shake = Math.max(st.shake, .12); st.rings.push({ x: e.x + e.f * 60, y: e.y - 30, t: 0, kind: 'ember' });
        if (body(p, e.x, e.x + e.f * 115, e.y - 76, e.y + 4)) hit(); }
      else if (e.next === 'charge') { e.mode = 'charge'; e.mt = 1.1; e.vx = e.f * 560 * Math.sqrt(sm); }
      else if (e.next === 'throw') { e.act = 0; throwBlade(st, e, p, l); e.mode = 'swing'; e.mt = .25; }
      return true;
    }
    if (e.mode === 'lunge') {
      e.mt -= dt;
      if (body(p, e.x - 14, e.x + 14, e.y - e.h, e.y)) { hit(); e.mt = Math.min(e.mt, .05); }
      if (e.mt <= 0 || (e.ground && e.mt < .3)) { e.mode = null; e.aiCd = rnd(1.5, 2.3) - .7 * l; }
      return !e.ground;
    }
    if (e.mode === 'swing') { e.mt -= dt; e.vx = lerp(e.vx, 0, Math.min(1, dt * 10)); if (e.mt <= 0) { e.mode = null; e.aiCd = rnd(1.6, 2.4) - .6 * l; } return true; }
    if (e.mode === 'charge') {
      e.mt -= dt; e.vx = e.f * 560 * Math.sqrt(sm);
      if (Math.random() < .5) sparks(st.P, e.x - e.f * 14, e.y - 6, .5, 1);
      if (body(p, e.x - 20, e.x + 20, e.y - e.h, e.y)) { hit(); e.mt = 0; }
      if (e.mt <= 0 || e.wall === e.f || !floorAt(e.x + e.f * 26, e.y)) { e.mode = 'swing'; e.mt = .6; e.vx = 0; st.shake = Math.max(st.shake, .1); }
      return true;
    }
    e.mode = null; return false;
  }

  function throwBlade(st, e, p, l) {
    // a straight throw at where the player will be, and a second blade at depth when they're on the same floor
    const ox = e.x + e.f * 16, oy = e.y - 34, sp = 540;
    const T = Math.hypot(p.x - ox, p.y - 28 - oy) / sp, tx = p.x + clamp(p.vx * T * (.4 + .5 * l), -200, 200), ty = p.y - 28 + (p.ground ? 0 : clamp(p.vy * T * .4, -120, 120));
    let a = Math.atan2(ty - oy, tx - ox);
    if (Math.abs(p.y - e.y) < 44) a = e.f > 0 ? 0 : PI;      // on the same floor it skims flat, as before
    st.proj.push({ x: ox, y: oy, vx: Co(a) * sp, vy: S(a) * sp, life: 1.8, blade: 1 });
    if (st.depth >= 10 && Math.abs(p.y - e.y) < 44) st.proj.push({ x: ox, y: oy - 34, vx: Co(a) * sp * .85, vy: 0, life: 2, blade: 1 }); // a high one, so a jump alone won't clear both
  }

  function hexer(st, e, p, dx, dy, dt, sm, l) {
    e.vx = e.ground ? lerp(e.vx, 0, Math.min(1, dt * 8)) : e.vx; e.f = Math.sign(dx) || 1; e.kiteCd = (e.kiteCd ?? 0) - dt;
    if (!e.ground) return true;
    // keep its distance: hop away when the player closes in
    if (Math.abs(dx) < 150 && Math.abs(dy) < 60 && e.kiteCd <= 0 && floorAt(e.x - e.f * 90, e.y) && !wallAt(e.x - e.f * 40, e.y - 30)) {
      e.kiteCd = 2.6 - l; e.vx = -e.f * 380; e.vy = -560; e.ground = false; return true;
    }
    e.shoot -= dt;
    if (e.tele > 0) { e.tele -= dt; if (e.tele <= 0) castHex(st, e, p, l); return true; }
    if (e.shoot <= 0 && Math.abs(dx) < 620) { e.shoot = rnd(2, 3) / sm - .5 * l; e.tele = e.teleMax = .45; }
    return true;
  }

  function lob(st, ox, oy, tx, ty, T) { st.proj.push({ x: ox, y: oy, vx: (tx - ox) / T, vy: (ty - oy - .5 * 900 * T * T) / T, life: 3 }); }
  function castHex(st, e, p, l) {
    const T = .9, ox = e.x + e.f * 14, oy = e.y - 70, ty = p.y - 28;
    const lead = clamp(p.vx * T * (.45 + .5 * l), -260, 260);
    lob(st, ox, oy, p.x + lead, ty, T);
    // deeper down they bracket you: one where you stand and one past where you're heading
    if (st.depth >= 7) { lob(st, ox, oy, p.x, ty, T * 1.1); lob(st, ox, oy, p.x + lead * 1.8 + (Math.sign(lead) || p.f) * 50, ty, T * .95); }
  }

  // gloomwings: drift to the player's back, shudder, then dive at where they're going
  function bat(st, e, p, dt, sm, hit) {
    const l = L(st);
    e.diveCd = (e.diveCd ?? rnd(1, 2.2)) - dt;
    if (e.hit > 0) { e.dive = 0; e.tele = 0; return false; }
    if (e.tele > 0) { e.tele -= dt; e.x += rnd(-1, 1) * 2; if (e.tele <= 0) {
        const T = .3, tx = p.x + clamp(p.vx * T * (.5 + .5 * l), -120, 120), ty = p.y - 30 + (p.ground ? 0 : clamp(p.vy * T * .5, -80, 80));
        const d = Math.hypot(tx - e.x, ty - e.y) || 1, v = 560 * Math.sqrt(sm); e.dvx = (tx - e.x) / d * v; e.dvy = (ty - e.y) / d * v; e.dive = .5; }
      return true; }
    if (e.dive > 0) {
      e.dive -= dt; e.x += e.dvx * dt; e.y += e.dvy * dt; e.f = e.dvx > 0 ? 1 : -1;
      if (Math.random() < .6) emit(st.P, { x: e.x, y: e.y, vx: rnd(-20, 20), vy: rnd(-20, 20), r: rnd(1.5, 3), col: '#1b0c10', life: .3, shrink: 1 });
      if (body(p, e.x - 10, e.x + 10, e.y - 10, e.y + 10)) { hit(); e.dive = 0; }
      if (wallAt(e.x, e.y - 8) || e.y > DA.h - TS) { e.x = e.px ?? e.x; e.y = e.py ?? e.y; e.dive = 0; }
      if (e.dive <= 0) e.diveCd = rnd(1.5, 2.6) - .6 * l;
      e.px = e.x; e.py = e.y;
      return true;
    }
    if (e.diveCd <= 0 && Math.hypot(e.x - p.x, e.y - p.y + 40) < 230 && busy(st) < tokens(st) + 1 && !wallAt((e.x + p.x) / 2, (e.y + p.y - 40) / 2)) {
      e.tele = e.teleMax = .32;
      // the rest of the flock joins in, a beat apart
      let n = 0; for (const o of st.E) if (o !== e && o.type === 'bat' && !o.dead && !(o.tele > 0) && !(o.dive > 0) && n < 2 && Math.hypot(o.x - e.x, o.y - e.y) < 240 && st.depth >= 4) { o.tele = o.teleMax = .32 + .14 * ++n; o.diveCd = 0; }
      return true; }
    return false;
  }
  // hover target offset: behind the player, each bat on its own slot
  function batX(st, e, p) { e.bs = lerp(e.bs ?? 0, -p.f * (70 + (e.o % 5) * 14), Math.min(1, .02 + .03 * L(st))); return e.bs; }

  // ---- bosses: each one has its own moves, and picks them by range ----
  const BOSS = [
    { name: 'warden', walk: 72 }, { name: 'king', walk: 66 }, { name: 'jarl', walk: 92 }, { name: 'umber', walk: 64 }];
  function bossPick(st, e, p, dx, dy, rage) {
    const i = e.look || 0, adx = Math.abs(dx), o = [];
    if (adx < 90 && dy < -70) return 'upper';                                 // no standing on its head
    if (i === 0) { o.push(['smash', 1.4]); if (adx < 240) o.push(['sweep', 2.2]); if (rage) o.push(['leap', .8]); if (adx > 220 && adx < 440 && Math.abs(dy) < 50) o.push(['pull', 2.4]); }
    if (i === 1) { o.push(['leap', 2.6], ['smash', 1]); if (rage) o.push(['rain', 1.4]); }
    if (i === 2) { o.push(['smash', 1.2]); if (adx > 170) o.push(['dash', 2.8]); if (rage) o.push(['leap', 1.2]); if (adx < 200) o.push(['sweep', 1]); }
    if (i === 3) { o.push(['leap', 1.8], ['rain', 1.5], ['smash', .7]); if (Math.abs(dy) < 40) o.push(['blink', 2.4]); }
    for (const q of o) if (q[0] === e.last) q[1] *= .3;
    let r = Math.random() * o.reduce((a, q) => a + q[1], 0);
    for (const q of o) if ((r -= q[1]) <= 0) return q[0];
    return 'smash';
  }
  const WIND = { pull: .55, smash: .75, sweep: .55, leap: .45, dash: .6, slash: .4, rain: .6, upper: .32, blink: .2 };
  function bwind(e, kind, rage) { e.ai = 'wind'; e.next = kind; e.at = e.windT = WIND[kind] * (rage ? .72 : 1); }

  function boss(st, e, p, dt, sm, hit) {
    const dx = p.x - e.x, dy = p.y - e.y, adx = Math.abs(dx), rage = e.hp < e.mhp / 2, i = e.look || 0, l = L(st);
    const bd = 1 + (st.depth >= 8 ? 1 : 0);
    e.at -= dt;
    if (e.ground && !e.landed) { e.landed = 1; st.shake = .45; st.rings.push({ x: e.x, y: e.y, t: 0, kind: 'slam', big: 1 }); }
    // at half health it roars and calls its dungeon's dead to fight beside it
    if (rage && !e.called && e.ground && (e.ai === 'walk' || e.ai === 'smash')) { e.called = 1; callAdds(st, e); }
    if (e.ai === 'walk') {
      e.f = Math.sign(dx) || 1;
      const want = adx < 70 ? 0 : e.f * BOSS[i].walk * sm * (rage ? 1.25 : 1);
      e.vx = lerp(e.vx, want, Math.min(1, dt * 3));
      if (e.at <= 0 && e.ground) startMove(st, e, p, bossPick(st, e, p, dx, dy, rage), rage, l);
    } else if (e.ai === 'wind') {
      e.vx *= Math.max(0, 1 - dt * 10);
      if (e.next === 'sweep' || e.next === 'upper' || e.next === 'smash') { if (e.at > e.windT * .5) e.f = Math.sign(dx) || e.f; }
      if (e.at <= 0) bossDo(st, e, p, dx, dy, rage, bd, hit);
    } else if (e.ai === 'leap') {
      if (e.at <= 0) { e.ai = 'walk'; e.at = .6; }
      else if (e.ground && e.vy >= 0 && e.at < 1.85) {
        e.ai = 'smash'; e.at = .6; st.shake = .45;
        st.rings.push({ x: e.x, y: e.y, t: 0, kind: 'slam', big: 1, red: 1 });
        st.quakes.push({ x: e.x, y: e.y, t: 0, dir: -1 }, { x: e.x, y: e.y, t: 0, dir: 1 });
        if (Math.abs(p.x - e.x) < 120 && Math.abs(p.y - e.y) < 70) hit(bd);
        if (i === 3 || (i === 1 && rage)) { const n = rage ? 5 : 3; for (let k = 0; k < n; k++) lob(st, e.x, e.y - 120, p.x + (k - (n - 1) / 2) * 90 + clamp(p.vx * .5, -120, 120), p.y - 28, .9); }
      }
    } else if (e.ai === 'pull') {
      // the chain runs out along the floor; whoever it catches is dragged in for a smash
      e.cx += e.f * 1100 * dt; e.vx = 0;
      if (Math.random() < .9) sparks(st.P, e.cx, e.y - 30, .5, 1, '#c9c2b8');
      if (!e.caught && p.dash <= 0 && p.hurt <= 0 && Math.abs(p.x - e.cx) < 30 && p.y - 56 < e.y - 10 && p.y > e.y - 80) {
        e.caught = 1; p.vx = Math.sign(e.x - p.x) * 760; p.vy = -260; p.ground = false; p.kick = .3; p.atk = null; st.shake = .25;
      }
      if (e.caught || Math.abs(e.cx - e.x) > 460 || wallAt(e.cx, e.y - 30)) { if (e.caught) { bwind(e, 'smash', true); e.at = e.windT = .32; } else { e.ai = 'smash'; e.at = .45; } }
    } else if (e.ai === 'dash') {
      e.vx = e.f * 940; if (Math.random() < .8) sparks(st.P, e.x - e.f * 20, e.y - 40, .8, 2);
      if (body(p, e.x - 30, e.x + 30, e.y - 120, e.y)) hit(bd);
      if (e.at <= 0 || e.wall === e.f || e.x < 70 || e.x > DA.w - 70) { e.vx = e.f * 120; e.ai = 'smash'; e.at = .7; st.shake = .2; }
    } else if (e.ai === 'smash' && e.at <= 0) {
      if (e.chain > 0) { e.chain--; e.chained = true; bwind(e, 'smash', true); e.at = e.windT = .38; }
      // below a quarter health it stops walking between moves and strings them together
      else if (e.hp < e.mhp / 4 && e.ground && !e.combo && Math.random() < .65) { e.combo = 1; startMove(st, e, p, bossPick(st, e, p, dx, dy, true), true, l); }
      else { e.combo = 0; e.ai = 'walk'; e.at = (rage ? rnd(.7, 1.2) : rnd(1.1, 1.8)) - .3 * l; }
    }
  }

  function startMove(st, e, p, k, rage, l) {
    e.last = k; bwind(e, k, rage);
    if (k === 'leap') { const T = 2 * 900 / GRV; e.tx = clamp(p.x + p.vx * T * (.5 + .4 * l), 60, DA.w - 60); e.ty = e.y; }
    if (k === 'rain') { const n = rage ? 7 : 5, c = p.x + clamp(p.vx * .5, -160, 160); e.ry = p.y; e.rx = []; for (let k2 = 0; k2 < n; k2++) e.rx.push(clamp(c + (k2 - (n - 1) / 2) * 68, 40, DA.w - 40)); }
  }
  const ADD = [['sh', 3, 52], ['dr', 4, 50], ['fg', 4, 56], ['sn', 3, 56]];
  function callAdds(st, e) {
    const [type, hp0, h] = ADD[e.look || 0], hp = hp0 * hpMul(st.depth);
    st.shake = .5; st.rings.push({ x: e.x, y: e.y - 60, t: 0, kind: 'slam', big: 1, red: 1 });
    st.banner = { text: 'IT CALLS ITS DEAD', sub: 'THE BOSS IS ENRAGED', t: 1.6, col: C.crimson };
    for (const sd of [-1, 1]) { const x = clamp(e.x + sd * 170, 60, DA.w - 60); if (!floorAt(x, e.y) || wallAt(x, e.y - 30)) continue;
      sparks(st.P, x, e.y - 30, 1.2, 14, C.crimson);
      st.E.push({ type, elite: null, x, y: e.y, vx: 0, vy: 0, hp, mhp: hp, o: rnd(0, 20), f: -sd, hit: 0, ground: true, sc: 1, w: 18, h, shoot: rnd(1, 2), plat: null, burnT: 0, aiCd: .8 }); }
  }

  function bossDo(st, e, p, dx, dy, rage, bd, hit) {
    const k = e.next;
    if (k === 'smash') {
      e.ai = 'smash'; e.at = .5; st.shake = .35; const sx = e.x + e.f * 60;
      st.quakes.push({ x: sx, y: e.y, t: 0, dir: -1 }, { x: sx, y: e.y, t: 0, dir: 1 });
      st.rings.push({ x: sx, y: e.y, t: 0, kind: 'slam', big: 1, red: 1 });
      if (Math.abs(p.x - sx) < 70 && Math.abs(p.y - e.y) < 90) hit(bd);
      if (rage && (e.look || 0) === 0 && !e.chained) e.chain = 1;             // the warden smashes twice when hurt
      e.chained = false;
    } else if (k === 'sweep') {
      // a low sweep along the floor: jump it
      e.ai = 'smash'; e.at = .55; st.shake = .2;
      const sides = rage ? [-1, 1] : [e.f];
      for (const sd of sides) { for (let k2 = 1; k2 <= 6; k2++) sparks(st.P, e.x + sd * k2 * 40, e.y - 16, .6, 2);
        if (body(p, e.x, e.x + sd * 250, e.y - 54, e.y + 4)) hit(bd); }
    } else if (k === 'leap') {
      const T = 2 * 900 / GRV; e.ai = 'leap'; e.at = 2; e.vy = -900; e.ground = false; e.vx = clamp((e.tx - e.x) / T, -660, 660); e.f = Math.sign(e.vx) || e.f;
    } else if (k === 'dash') { e.ai = 'dash'; e.at = .55; e.f = Math.sign(dx) || e.f; }
    else if (k === 'upper') {
      e.ai = 'smash'; e.at = .5; st.shake = .25; st.rings.push({ x: e.x, y: e.y - 150, t: 0, kind: 'ember' });
      if (body(p, e.x - 80, e.x + 80, e.y - 300, e.y)) hit(bd);
    } else if (k === 'blink') {
      // step out of the dark behind the player, then cut
      const sd = -p.f, cand = [p.x + sd * 110, p.x - sd * 110];
      for (const tx of cand) if (tx > 60 && tx < DA.w - 60 && floorAt(tx, e.y) && !wallAt(tx, e.y - 40) && !wallAt(tx, e.y - 100)) {
        sparks(st.P, e.x, e.y - 60, 1.4, 16); e.x = tx; e.vx = 0; e.f = Math.sign(p.x - tx) || 1; sparks(st.P, e.x, e.y - 60, 1.4, 16); break; }
      bwind(e, 'slash', rage);
    } else if (k === 'slash') {
      e.ai = 'smash'; e.at = .45; st.shake = .2; st.rings.push({ x: e.x + e.f * 70, y: e.y - 50, t: 0, kind: 'ember' });
      if (body(p, e.x, e.x + e.f * 160, e.y - 130, e.y + 4)) hit(bd);
    } else if (k === 'rain') {
      e.ai = 'smash'; e.at = .8;
      for (const x of e.rx || []) { let y = p.y - 380; while (y < p.y - 80 && wallAt(x, y)) y += TS; st.proj.push({ x, y: Math.max(30, y), vx: 0, vy: 40, life: 3 }); }
    } else if (k === 'pull') { e.ai = 'pull'; e.cx = e.x + e.f * 30; e.caught = 0; e.f = Math.sign(dx) || e.f; }
    else { e.ai = 'walk'; e.at = 1; }
  }

  // ---- danger markers for every wind-up ----
  function draw(ctx, st) {
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    for (const e of st.E) {
      if (e.dead) continue;
      const k = e.teleMax ? clamp(1 - e.tele / e.teleMax, 0, 1) : 0;
      if (e.type !== 'boss' && e.tele > 0) {
        const a = .35 + .55 * k, top = e.y - e.h - 18;
        ctx.fillStyle = `rgba(255,70,60,${a})`; ctx.shadowColor = C.crimson; ctx.shadowBlur = 12;
        ctx.beginPath(); ctx.moveTo(e.x - 4, top - 12); ctx.lineTo(e.x + 4, top - 12); ctx.lineTo(e.x + 1.5, top); ctx.lineTo(e.x - 1.5, top); ctx.fill(); circ(ctx, e.x, top + 5, 2.2);
        if (e.next === 'swing') { ctx.strokeStyle = `rgba(229,56,59,${.25 + .4 * k})`; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(e.x + e.f * 40, e.y - 30, 60, -1.3, 1.3); ctx.stroke(); }
        if (e.next === 'charge' || e.next === 'lunge') { const len = e.next === 'charge' ? 300 : 150; const g = ctx.createLinearGradient(e.x, 0, e.x + e.f * len, 0); g.addColorStop(0, `rgba(229,56,59,${.35 * k})`); g.addColorStop(1, 'rgba(229,56,59,0)'); ctx.fillStyle = g; ctx.fillRect(Math.min(e.x, e.x + e.f * len), e.y - 4, len, 4); }
      }
      if (e.type === 'boss' && e.ai === 'wind') {
        const kk = clamp(1 - e.at / (e.windT || .75), 0, 1), a = .18 + .34 * kk, red = `rgba(229,56,59,${a})`;
        ctx.fillStyle = red; ctx.strokeStyle = `rgba(255,90,80,${a + .2})`; ctx.lineWidth = 2;
        if (e.next === 'sweep') for (const sd of (e.hp < e.mhp / 2 ? [-1, 1] : [e.f])) ctx.fillRect(Math.min(e.x, e.x + sd * 250), e.y - 54, 250, 54);
        if (e.next === 'pull') ctx.fillRect(Math.min(e.x, e.x + e.f * 460), e.y - 80, 460, 70 * kk);
        if (e.next === 'slash') ctx.fillRect(Math.min(e.x, e.x + e.f * 160), e.y - 130, 160, 130);
        if (e.next === 'upper') ctx.fillRect(e.x - 80, e.y - 300, 160, 300);
        if (e.next === 'dash') ctx.fillRect(Math.min(e.x, e.x + e.f * 520), e.y - 110, 520, 110 * kk);
        if (e.next === 'smash') { const sx = e.x + e.f * 60; ctx.fillRect(sx - 70, e.y - 6, 140, 6); }
        if (e.next === 'leap' && e.tx != null) { ctx.beginPath(); ctx.ellipse(e.tx, e.y - 2, 120 * (.4 + .6 * kk), 12, 0, 0, TAU); ctx.fill(); ctx.stroke(); }
        if (e.next === 'rain' && e.rx) for (const x of e.rx) { ctx.beginPath(); ctx.ellipse(x, (e.ry ?? st.p.y) - 2, 18, 5, 0, 0, TAU); ctx.fill(); }
      }
      if (e.type === 'boss' && e.ai === 'pull') { ctx.strokeStyle = 'rgba(201,194,184,.9)'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(e.x + e.f * 20, e.y - 70); ctx.lineTo(e.cx, e.y - 30); ctx.stroke(); ctx.fillStyle = '#c9c2b8'; circ(ctx, e.cx, e.y - 30, 7); }
      if (e.type === 'boss' && e.ai === 'leap' && e.tx != null) { ctx.fillStyle = 'rgba(229,56,59,.3)'; ctx.beginPath(); ctx.ellipse(e.tx, (e.ty ?? FLOOR) - 2, 120, 12, 0, 0, TAU); ctx.fill(); }
    }
    ctx.restore();
  }
  return { ground, bat, batX, boss, draw };
})();
