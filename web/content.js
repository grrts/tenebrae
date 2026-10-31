// Dungeon enemies, ported from the Godot prototype (src/enemy.gd).
// Drowned (the Well) crouch and pounce, Forged (the Bladeworks) throw spinning
// blades flat along the floor, Snuffers (the Throne) blink beside you and slash.
const CONTENT = (() => {
  const EYES = { dr: '#3fd6c4', fg: '#ff8a5c', sn: '#b44dff' };
  // returns true when it handled the enemy this frame
  function ai(st, e, p, dx, dy, dt, sm, hit) {
    if (e.type === 'dr') {
      e.act = (e.act || 0); e.cd = (e.cd ?? rnd(1, 2)) - dt;
      if (e.act > 0) { e.act -= dt; e.vx = 0; if (e.act <= 0) { e.vx = clamp(dx * 1.6, -560, 560); e.vy = -640; e.ground = false; e.pounce = .9; } return true; }
      if (e.cd <= 0 && Math.abs(dx) < 300 && Math.abs(dy) < 80) { e.act = .4; e.cd = rnd(2, 2.8); e.f = Math.sign(dx) || 1; return true; }
      return false;
    }
    if (e.type === 'fg') {
      e.act = (e.act || 0); e.cd = (e.cd ?? rnd(1, 2)) - dt;
      if (e.act > 0) { e.act -= dt; e.vx = 0; if (e.act <= 0) st.proj.push({ x: e.x + e.f * 16, y: e.y - 34, vx: e.f * 520, vy: 0, life: 1.8, blade: 1 }); return true; }
      if (e.cd <= 0 && Math.abs(dy) < 50 && Math.abs(dx) < 640) { e.f = Math.sign(dx) || 1; e.act = .45; e.cd = rnd(2.2, 3.2); return true; }
      return false;
    }
    if (e.type === 'sn') {
      e.vx = 0; e.act = (e.act || 0); e.cd = (e.cd ?? rnd(1.5, 2.5)) - dt;
      if (e.act > 0) {
        const before = e.act; e.act -= dt;
        if (before > .1 && e.act <= .1) {
          st.rings.push({ x: e.x + e.f * 45, y: e.y - 30, t: 0, kind: 'ember' });
          const fx = (p.x - e.x) * e.f;
          if (fx > -10 && fx < 95 && Math.abs((e.y - e.h / 2) - (p.y - 28)) < 50) hit();
        }
        return true;
      }
      if (e.cd <= 0 && p.ground && Math.hypot(dx, dy) < 700) {
        for (const side of [-p.f, p.f]) {
          const tx = p.x + side * 70;
          if (!isSolid(DA, Math.floor(tx / TS), Math.floor((p.y - 20) / TS)) && isSolid(DA, Math.floor(tx / TS), Math.floor((p.y + 20) / TS))) {
            sparks(st.P, e.x, e.y - 28, 1, 10); e.x = tx; e.y = p.y; e.vy = 0; e.f = p.x > e.x ? 1 : -1; e.act = .5; e.cd = rnd(2.6, 3.6); sparks(st.P, e.x, e.y - 28, 1, 10);
            break;
          }
        }
      }
      return true;
    }
    return false;
  }
  function draw(ctx, e, st, tt, look) {
    const l = Object.assign({}, look, look.eyes === C.gold ? {} : { eyes: EYES[e.type] });
    if (e.type === 'dr') {
      const J = drawShambler(ctx, e.x, e.y + (e.act > 0 ? 8 : 0), .62 * e.sc, tt, e.f, l);
      return J;
    }
    const J = drawShambler(ctx, e.x, e.y, (e.type === 'fg' ? .7 : .66) * e.sc, tt, e.f, l);
    ctx.save();
    if (e.type === 'fg') { ctx.fillStyle = 'rgba(255,138,92,.55)'; ctx.shadowColor = '#ff8a5c'; ctx.shadowBlur = 12; circ(ctx, e.x + e.f * 14, e.y - 36, e.act > 0 ? 7 : 4); }
    else {
      // the snuffer: a cone on a long pole, raised before the slash
      const a = e.act > .1 ? -2.2 : e.act > 0 ? .3 : -1.2, hx = e.x + e.f * 10, hy = e.y - 40;
      const tx = hx + Math.cos(a) * 50 * e.f, ty = hy + Math.sin(a) * 50;
      ctx.strokeStyle = '#5a524c'; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(tx, ty); ctx.stroke();
      ctx.fillStyle = C.shade; ctx.beginPath(); ctx.arc(tx, ty, 7, 0, TAU); ctx.fill();
    }
    ctx.restore();
    return J;
  }
  function drawBlade(ctx, q, st) {
    ctx.save(); ctx.strokeStyle = '#ffd2b8'; ctx.shadowColor = '#ff8a5c'; ctx.shadowBlur = 14; ctx.lineWidth = 2.5;
    for (let i = 0; i < 3; i++) { const a = st.time * 18 + i * TAU / 3; ctx.beginPath(); ctx.moveTo(q.x, q.y); ctx.lineTo(q.x + Math.cos(a) * 10, q.y + Math.sin(a) * 10); ctx.stroke(); }
    ctx.restore();
  }
  return { ai, draw, drawBlade };
})();
