/* ===================== STORY: chapters, anime cutscenes, souls-like death =====================
   Injected by build_story.py into the playtest build, inside the same scope as the game.
   Story bible: docs/STORY.md. Every scene plays once per browser (localStorage); ?story replays them all.
   Test jumps: ?chapter=2..4 starts at that dungeon, ?final starts two seconds before Saint Umber. */
const STORY = (() => {
  const SERIF = '"Cinzel", Georgia, serif', ITAL = '"Cormorant Garamond", Georgia, serif';
  const DEATH_T = 5.4;
  const q = new URLSearchParams(location.search);
  let seen = {};
  try { seen = JSON.parse(localStorage.getItem('tenebrae.seen') || '{}') || {}; } catch (e) { seen = {}; }
  if (q.has('story')) seen = {};
  const save = () => { try { localStorage.setItem('tenebrae.seen', JSON.stringify(seen)); } catch (e) {} };
  let skipAll = false, tap = false, jumpUsed = false;
  addEventListener('keydown', e => { if (e.code === 'Escape' || e.code === 'Enter') { skipAll = true; e.preventDefault(); } });
  addEventListener('pointerdown', () => { tap = true; });

  const CH = [
    { n: 'I', name: 'THE PIT OF PSALMS', from: 1, boss: 'THE CHAIN WARDEN', who: 'BROTHER HALVARD' },
    { n: 'II', name: 'THE DROWNED WELL', from: 5, boss: 'THE HOLLOW KING', who: 'RURIK THE DROWNED' },
    { n: 'III', name: 'THE BLADEWORKS', from: 9, boss: 'THE ASHEN JARL', who: 'JARL SIGVALD' },
    { n: 'IV', name: 'THE HOLLOW THRONE', from: 13, boss: 'SAINT UMBER', who: 'THE CANDLE-EATER' }
  ];
  const chOf = d => d >= 13 ? 3 : d >= 9 ? 2 : d >= 5 ? 1 : 0;

  /* ---------- small drawing kit ---------- */
  const eo = easeOut, k01 = (t, a, d) => clamp((t - a) / d, 0, 1);
  const hash = i => { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };
  const fill = (c, W, H, col) => { c.fillStyle = col; c.fillRect(0, 0, W, H); };
  const vgrad = (c, W, H, a, b) => { const g = c.createLinearGradient(0, 0, 0, H); g.addColorStop(0, a); g.addColorStop(1, b); c.fillStyle = g; c.fillRect(0, 0, W, H); };
  function glow(c, x, y, r, rgb, a) {
    c.save(); c.globalCompositeOperation = 'lighter'; const g = c.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, `rgba(${rgb},${a})`); g.addColorStop(1, `rgba(${rgb},0)`); c.fillStyle = g; c.fillRect(x - r, y - r, r * 2, r * 2); c.restore();
  }
  function vig(c, W, H, a = .85) {
    const g = c.createRadialGradient(W / 2, H / 2, H * .3, W / 2, H / 2, W * .7); g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, `rgba(0,0,0,${a})`);
    c.fillStyle = g; c.fillRect(0, 0, W, H);
  }
  function snow(c, W, H, T, n = 70, wind = 1, a = .55) {
    c.save(); c.fillStyle = `rgba(226,222,236,${a})`;
    for (let i = 0; i < n; i++) { const sp = 22 + hash(i) * 46, x = (((hash(i + 7) * W + T * wind * sp + S(T * .7 + i) * 12) % (W + 20)) + W + 20) % (W + 20) - 10, y = (hash(i + 3) * H + T * sp) % H; circ(c, x, y, .7 + hash(i + 11) * 1.7); }
    c.restore();
  }
  function embers(c, W, H, T, n = 40, rgb = '255,150,80', spd = 60) {
    c.save(); c.globalCompositeOperation = 'lighter';
    for (let i = 0; i < n; i++) { const sp = spd * (.5 + hash(i)), x = hash(i + 5) * W + S(T * 1.3 + i) * 22, y = H + 10 - ((hash(i + 9) * (H + 20) + T * sp) % (H + 20));
      c.fillStyle = `rgba(${rgb},${.35 + .55 * hash(i + 2)})`; circ(c, x, y, 1 + hash(i + 4) * 2.2); }
    c.restore();
  }
  // anime focus lines converging on a point, re-drawn every frame so they flicker
  function focus(c, W, H, cx, cy, T, rgb = '255,255,255', a = .85, n = 120, r0 = 160) {
    c.save(); c.fillStyle = `rgba(${rgb},${a})`; const fr = Math.floor(T * 20), R = Math.hypot(W, H);
    for (let i = 0; i < n; i++) { const ang = hash(i + fr * 131) * TAU, w = .003 + hash(i * 3 + fr) * .011, r = r0 * (.7 + hash(i * 7 + fr) * .9);
      c.beginPath(); c.moveTo(cx + Co(ang) * r, cy + S(ang) * r); c.lineTo(cx + Co(ang - w) * R, cy + S(ang - w) * R); c.lineTo(cx + Co(ang + w) * R, cy + S(ang + w) * R); c.fill(); }
    c.restore();
  }
  function streaks(c, W, H, T, vertical, rgb = '255,255,255', a = .55, n = 60) {
    c.save(); c.fillStyle = `rgba(${rgb},${a})`; const fr = Math.floor(T * 24);
    for (let i = 0; i < n; i++) { const p = hash(i + fr * 17), L = 80 + hash(i * 5 + fr) * 280, th = 1 + hash(i * 9) * 2.6;
      if (vertical) c.fillRect(p * W, hash(i * 3 + fr) * H * 1.3 - L / 2, th, L); else c.fillRect(hash(i * 3 + fr) * W * 1.3 - L / 2, p * H, L, th); }
    c.restore();
  }
  // big manga sound effect that pops in
  function sfx(c, s, x, y, px, rot, col, t, stroke = '#000') {
    const k = clamp(t * 7, 0, 1), sc = 1.8 - eo(k) * .8;
    c.save(); c.translate(x, y); c.rotate(rot); c.scale(sc, sc); c.globalAlpha = k; c.font = `900 ${px}px ${DISP}`; c.textAlign = 'center'; c.lineJoin = 'round';
    c.lineWidth = px * .18; c.strokeStyle = stroke; c.strokeText(s, 0, 0); c.fillStyle = col; c.fillText(s, 0, 0); c.restore();
  }
  function spaced(c, s, x, y, sp) {
    c.textAlign = 'left'; const ws = [...s].map(ch => c.measureText(ch).width), tw = ws.reduce((a, b) => a + b, 0) + sp * (s.length - 1);
    let xx = x - tw / 2; [...s].forEach((ch, i) => { c.fillText(ch, xx, y); xx += ws[i] + sp; });
  }
  function card(c, W, H, t, d, title, sub, col = C.crimson, over) {
    fill(c, W, H, '#040304'); embers(c, W, H, t + 3, 50, col === C.gold ? '242,180,58' : '229,56,59', 40);
    if (over) over(c, t);
    const k = eo(k01(t, 0, .35)), out = clamp((d - t) / .4, 0, 1);
    c.save(); c.translate(W / 2, H / 2); c.rotate(-.05); const bw = W * 1.3 * k; c.globalAlpha = out; c.fillStyle = col; c.shadowColor = col; c.shadowBlur = 20;
    c.fillRect(-bw / 2, 6, bw, 3); c.restore();
    const a = k01(t, .12, .5) * out;
    c.save(); c.globalAlpha = a; c.font = `800 ${title.length > 16 ? 50 : title.length > 11 ? 62 : 84}px ${SERIF}`; c.fillStyle = '#f3ebe0'; c.shadowColor = col; c.shadowBlur = 26;
    spaced(c, title, W / 2, H / 2 - 14, 4 + (1 - eo(a)) * 18); c.shadowBlur = 0;
    c.globalAlpha = k01(t, .5, .5) * out; c.font = `600 13px ${MONO}`; c.fillStyle = col; spaced(c, sub, W / 2, H / 2 + 40, 4); c.restore();
  }
  // boss name plate: a crimson slab slams in on the diagonal
  function nameCard(c, W, H, t, who, title, col = C.crimson) {
    const k = eo(k01(t, 0, .35)), off = (1 - k) * -W, y0 = H * .6;
    c.save(); c.translate(off, 0);
    c.fillStyle = '#000'; c.beginPath(); c.moveTo(-40, y0 - 6); c.lineTo(W * .82, y0 - 50); c.lineTo(W * .8, y0 + 64); c.lineTo(-40, y0 + 88); c.fill();
    c.fillStyle = col; c.beginPath(); c.moveTo(-40, y0); c.lineTo(W * .78, y0 - 40); c.lineTo(W * .76, y0 + 56); c.lineTo(-40, y0 + 80); c.fill();
    c.font = `600 13px ${MONO}`; c.fillStyle = '#120708'; spaced(c, who, W * .36, y0 + 2, 5);
    c.font = `800 52px ${SERIF}`; c.lineWidth = 7; c.strokeStyle = '#000'; c.textAlign = 'center';
    c.save(); c.translate(W * .36, y0 + 54); c.rotate(-.045); c.strokeText(title, 0, 0); c.fillStyle = '#fff4ea'; c.fillText(title, 0, 0); c.restore();
    c.restore();
  }
  function eyesClose(c, W, H, t, col, o = {}) {
    const open = eo(k01(t, o.delay || .15, .3));
    vgrad(c, W, H, '#07060a', '#0d080a');
    c.save(); c.translate(W / 2 + (o.dx || 0), H / 2 + (o.dy || 0)); c.scale(o.sc || 1, o.sc || 1);
    c.fillStyle = '#0b0a0e'; circ(c, 0, 420, 620);
    c.strokeStyle = o.rim || 'rgba(255,128,88,.55)'; c.lineWidth = 10; c.beginPath(); c.arc(0, 420, 618, PI * 1.12, PI * 1.5); c.stroke();
    c.fillStyle = col; c.shadowColor = col; c.shadowBlur = 50;
    for (const ex of [-170, 140]) { c.beginPath(); c.ellipse(ex, -10, 82, 2 + 24 * open * (o.slit ? .45 : 1), (ex < 0 ? 1 : -1) * (o.tilt || .08), 0, TAU); c.fill(); }
    if (o.third) { c.beginPath(); c.ellipse(-15, -120, 40, 2 + 16 * open, 0, 0, TAU); c.fill(); }
    c.shadowBlur = 0;
    if (open > .9) { c.fillStyle = 'rgba(255,255,255,.9)'; for (const ex of [-170, 140]) circ(c, ex + 30, -16, 5); }
    c.restore();
  }
  function moon(c, x, y, r) { glow(c, x, y, r * 4, '200,190,220', .22); c.fillStyle = '#e7e0ee'; circ(c, x, y, r); c.fillStyle = 'rgba(160,150,175,.35)'; circ(c, x + r * .3, y - r * .2, r * .25); circ(c, x - r * .35, y + r * .3, r * .18); }
  function raven(c, x, y, s, T) {
    const w = S(T * 9) * .6; c.save(); c.translate(x, y); c.scale(s, s); c.fillStyle = '#030203';
    c.beginPath(); c.moveTo(-22, -8 * w - 4); c.quadraticCurveTo(-10, -2, 0, 0); c.quadraticCurveTo(10, -2, 22, -8 * w - 4); c.quadraticCurveTo(10, 4, 0, 4); c.quadraticCurveTo(-10, 4, -22, -8 * w - 4); c.fill();
    c.beginPath(); c.ellipse(0, 2, 7, 3, 0, 0, TAU); c.fill(); c.restore();
  }
  function abbey(c, x, y, s, win = 'rgba(242,180,58,.9)', lit = 1) {
    c.save(); c.translate(x, y); c.scale(s, s); c.fillStyle = '#040305';
    c.beginPath(); c.moveTo(-520, 260); c.lineTo(-300, 50); c.lineTo(-160, 22); c.lineTo(170, 14); c.lineTo(320, 70); c.lineTo(520, 260); c.fill();
    c.fillRect(-130, -60, 260, 84); c.beginPath(); c.moveTo(-138, -60); c.lineTo(0, -128); c.lineTo(138, -60); c.fill();
    c.fillRect(-175, -160, 56, 184); c.beginPath(); c.moveTo(-181, -160); c.lineTo(-147, -260); c.lineTo(-113, -160); c.fill();
    c.fillRect(110, -112, 44, 136); c.beginPath(); c.moveTo(104, -112); c.lineTo(132, -186); c.lineTo(160, -112); c.fill();
    if (lit) { c.fillStyle = win; c.shadowColor = win; c.shadowBlur = 12; c.globalAlpha = lit;
      for (let i = -3; i <= 3; i++) { c.fillRect(i * 32 - 4, -36, 8, 18); } c.fillRect(-151, -120, 8, 16); c.fillRect(128, -84, 8, 14); circ(c, 0, -82, 9); }
    c.restore();
  }
  function bigHearse(c, x, y, sc, out, hidden, T) { c.save(); c.translate(x, y); c.scale(sc, sc); hearse(c, -75, 0, out + 1, hidden, T); c.restore(); }
  function sea(c, W, y, T, col = '#06100f', hi = 'rgba(120,200,190,.18)') {
    c.fillStyle = col; c.beginPath(); c.moveTo(0, y);
    for (let x = 0; x <= W; x += 16) c.lineTo(x, y + S(x * .02 + T * 1.6) * 5 + S(x * .051 - T) * 3);
    c.lineTo(W, 1e4); c.lineTo(0, 1e4); c.fill();
    c.strokeStyle = hi; c.lineWidth = 1.5; for (let r = 0; r < 6; r++) { c.beginPath(); const yy = y + 18 + r * 22; for (let x = 0; x <= W; x += 24) { const v = yy + S(x * .03 + T * 2 + r) * 3; x ? c.lineTo(x, v) : c.moveTo(x, v); } c.stroke(); }
  }
  function prow(c, x, y, s, tilt) {
    c.save(); c.translate(x, y); c.rotate(tilt); c.scale(s, s); c.fillStyle = '#020303';
    c.beginPath(); c.moveTo(-60, 40); c.quadraticCurveTo(-30, -20, 0, -60); c.quadraticCurveTo(20, -100, 6, -130); c.quadraticCurveTo(30, -118, 34, -100); c.lineTo(18, -96);
    c.quadraticCurveTo(28, -40, 30, 40); c.fill(); c.fillStyle = C.crimson; c.shadowColor = C.crimson; c.shadowBlur = 8; circ(c, 18, -112, 2.5); c.restore();
  }
  // the Wick: the player's stickman, drawn with the game's own rig
  const POSE = {
    stand: { lean: .06, tilt: .05, legs: [[-.12, -.08], [.16, -.1]], arms: [[-.15, .25], [.2, .3]], h: 66 },
    ready: { lean: .28, tilt: -.05, legs: [[-.55, -.35], [.65, -.8]], arms: [[-.5, .7], [1.3, .45]], h: 56 },
    kneel: { lean: .35, tilt: .5, legs: [[-.05, -1.5], [1.45, -1.45]], arms: [[.3, .3], [.75, .45]], h: 36 },
    strike: { lean: .75, tilt: -.2, legs: [[-1.05, -.3], [1.05, -1.15]], arms: [[-1.7, .3], [1.75, .05]], h: 48 },
    look: { lean: -.1, tilt: -.5, legs: [[-.1, -.05], [.12, -.08]], arms: [[-.1, .2], [.12, .25]], h: 66 },
    walk: { lean: .12, tilt: .1, legs: [[-.4, -.15], [.45, -.3]], arms: [[.3, .2], [-.2, .3]], h: 64 },
    dive: { lean: 0, tilt: -.2, legs: [[-.08, -.05], [.12, -.45]], arms: [[2.95, .1], [3.05, .1]], h: 66 },
    hold: { lean: .2, tilt: .3, legs: [[-.12, -.08], [.16, -.1]], arms: [[1.2, 1.2], [1.3, 1.1]], h: 66 }
  };
  function wick(c, x, y, s, name, T, o = {}) {
    const P = POSE[name], J = rig(Object.assign({ x, y: y - P.h * s, f: o.f || 1, s }, P));
    if (o.sil) paint(c, J, { body: o.sil, back: o.sil, rim: false });
    else drawPlayer(c, J, T * 1.6, o.wind ?? 1.3, o.lift ?? .1);
    if (!o.sil) eyes(c, J, { eyes: o.eyes || C.gold, glow: 14 });
    if (o.blade !== false) blade(c, J.armF.ex, J.armF.ey, o.ba ?? J.armF.can, 'katana', s * .94, o.bg ?? .7);
    return J;
  }
  function hild(c, x, y, s, name, T, o = {}) {
    const P = POSE[name], J = rig(Object.assign({ x, y: y - P.h * s, f: o.f || 1, s, build: { k: 1.05 } }, P));
    const col = o.sil || '#15111a';
    c.fillStyle = col; c.beginPath(); c.moveTo(J.hip[0] - 14 * s, J.hip[1] - 20 * s); c.lineTo(J.hip[0] + 14 * s, J.hip[1] - 20 * s); c.lineTo(J.hip[0] + 30 * s, y); c.lineTo(J.hip[0] - 30 * s, y); c.fill();
    paint(c, J, o.sil ? { body: col, back: col, rim: false, hood: true } : { body: col, back: '#231c26', rim: 'rgba(242,180,58,.75)', hood: true, eyes: '#cfd8ff', glow: 10 });
    return J;
  }
  const candleCrown = (lit, flame = C.violet) => (c2, J2) => {
    const [x, y, r] = J2.head; c2.save();
    for (let i = -3; i <= 3; i++) { const a = i * .34, h = r * (1.1 - Math.abs(i) * .12);
      c2.save(); c2.translate(x + S(a) * r * .95, y - Co(a) * r * .95); c2.rotate(a); c2.fillStyle = '#d8cdbb'; c2.fillRect(-r * .1, -h, r * .2, h);
      if (i + 3 < lit) { c2.fillStyle = flame; c2.shadowColor = flame; c2.shadowBlur = 14; c2.beginPath(); c2.ellipse(0, -h - r * .25, r * .13, r * .27, 0, 0, TAU); c2.fill(); }
      c2.restore(); }
    c2.restore();
  };
  const antlers = (c2, J2, col) => {
    const [x, y, r] = J2.head; c2.save(); c2.strokeStyle = col; c2.lineWidth = r * .2; c2.lineCap = 'round';
    for (const sd of [-1, 1]) { c2.beginPath(); c2.moveTo(x + sd * r * .45, y - r * .7); c2.quadraticCurveTo(x + sd * r * 1.7, y - r * 1.2, x + sd * r * 1.4, y - r * 2.7);
      c2.moveTo(x + sd * r * 1.3, y - r * 1.3); c2.lineTo(x + sd * r * 2.1, y - r * 1.8); c2.moveTo(x + sd * r * 1.5, y - r * 2.0); c2.lineTo(x + sd * r * 2.0, y - r * 2.6); c2.stroke(); }
    c2.restore();
  };
  const LOOK = [
    { eyes: C.crimson },
    { headExtra: crownHead },
    { headExtra: antlers, eyes: C.gold, rim: 'rgba(255,170,80,.95)' },
    { headExtra: candleCrown(7), eyes: C.violet, rim: 'rgba(180,77,255,.9)' }
  ];
  function chains(c, W, H, T, n = 9, drop = 1) {
    c.save(); c.strokeStyle = '#4a4248'; c.lineWidth = 4;
    for (let i = 0; i < n; i++) { const x = hash(i + 40) * W, len = (H * .4 + hash(i) * H * .5) * drop, sw = S(T * 2 + i) * 6;
      for (let y = -10; y < len; y += 16) { c.beginPath(); c.ellipse(x + sw * y / len, y, 4, 8, (y / 16) % 2 ? 0 : PI / 2 * .0, 0, TAU); c.stroke(); } }
    c.restore();
  }
  function stairs(c, W, H, T, glowCol = '180,77,255') {
    vgrad(c, W, H, '#020103', '#09040c'); glow(c, W / 2, H * .3, 220, glowCol, .25);
    for (let i = 0; i < 26; i++) { const k = 1 - (i + (T * .6) % 1) / 26, y = H * .3 + Math.pow(k, 2.2) * H * .9, w = 30 + Math.pow(k, 2.2) * W * 1.1;
      c.fillStyle = `rgba(${40 + k * 40},${30 + k * 26},${36 + k * 30},1)`; c.fillRect(W / 2 - w / 2, y, w, 4 + k * 26); c.fillStyle = 'rgba(0,0,0,.6)'; c.fillRect(W / 2 - w / 2, y + 4 + k * 22, w, 4 + k * 6); }
  }
  function forge(c, W, H, T) {
    vgrad(c, W, H, '#0b0503', '#1b0904'); glow(c, W / 2, H * .8, 420, '255,110,40', .35);
    for (let i = 0; i < 4; i++) { const x = W * (.15 + i * .23), ph = T * 3 + i * 1.6, up = Math.max(0, S(ph)), y = H * .2 + (1 - up) * H * .32;
      c.fillStyle = '#060303'; c.fillRect(x - 4, 0, 8, y); c.fillRect(x - 46, y, 92, 54); c.fillRect(x - 60, H * .78, 120, 30); c.fillRect(x - 30, H * .78 + 30, 60, 80);
      if (up < .08) glow(c, x, H * .78, 120, '255,180,90', .6); }
    embers(c, W, H, T, 70, '255,160,70', 120);
  }
  function crown(c, x, y, s, split = 0, T = 0) {
    c.save(); c.translate(x, y); c.scale(s, s);
    for (const sd of [-1, 1]) { c.save(); c.translate(sd * split * 40, split * 20); c.rotate(sd * split * .35);
      c.beginPath(); c.rect(sd < 0 ? -80 : 0, -100, 80, 200); c.clip();
      c.fillStyle = '#2a2018'; c.strokeStyle = 'rgba(242,180,58,.9)'; c.lineWidth = 3;
      c.beginPath(); c.moveTo(-60, 20); c.lineTo(-70, -40); c.lineTo(-35, -10); c.lineTo(0, -60); c.lineTo(35, -10); c.lineTo(70, -40); c.lineTo(60, 20); c.closePath(); c.fill(); c.stroke();
      c.restore(); }
    c.fillStyle = C.crimson; c.shadowColor = C.crimson; c.shadowBlur = 20; if (!split) circ(c, 0, -5, 9);
    if (split) { glow(c, 0, 0, 90 * split, '242,180,58', .7); c.strokeStyle = C.gold; c.lineWidth = 3; c.shadowColor = C.gold; c.beginPath(); c.moveTo(-26, 18); c.lineTo(0, -22); c.lineTo(26, 18); c.closePath(); c.stroke(); }
    c.restore();
  }
  function ash(c, x, y, T, n, spread, rgb = '70,60,58') {
    c.save(); for (let i = 0; i < n; i++) { const u = (T * .5 + hash(i)) % 1, xx = x + (hash(i + 3) - .5) * spread + u * 60 * (hash(i + 8) - .3), yy = y - u * 180 * (.5 + hash(i + 5));
      c.fillStyle = i % 5 ? `rgba(${rgb},${1 - u})` : `rgba(242,180,58,${1 - u})`; circ(c, xx, yy, 1.5 + hash(i + 1) * 2); } c.restore();
  }
  function panels(c, W, H, top, bot) {
    c.save(); c.beginPath(); c.moveTo(0, 0); c.lineTo(W, 0); c.lineTo(W, H * .42); c.lineTo(0, H * .56); c.clip(); top(); c.restore();
    c.save(); c.beginPath(); c.moveTo(0, H * .56 + 10); c.lineTo(W, H * .42 + 10); c.lineTo(W, H); c.lineTo(0, H); c.clip(); bot(); c.restore();
    c.strokeStyle = '#fff'; c.lineWidth = 8; c.beginPath(); c.moveTo(0, H * .56 + 5); c.lineTo(W, H * .42 + 5); c.stroke();
  }
  const BG = (c, W, H) => vgrad(c, W, H, '#07060b', '#120a0d');
  const SIL = '#000';

  /* ---------- the script ---------- */
  // each shot: d seconds, draw(c, t, W, H), say [speaker, line], flash, shake, bars
  const SC = {};
  SC.prologue = [
    { d: 5, bars: false, draw(c, t, W, H) { fill(c, W, H, '#030203'); snow(c, W, H, t, 50, .4, .35);
      c.save(); c.globalAlpha = k01(t, .3, 1.2); c.font = `800 64px ${SERIF}`; c.fillStyle = '#e9e1d6'; spaced(c, 'THE NORROW', W / 2, H / 2 - 6, 14);
      c.globalAlpha = k01(t, 1.6, 1.2); c.font = `italic 500 24px ${ITAL}`; c.fillStyle = '#b6aaa0'; c.textAlign = 'center'; c.fillText('In the winter the sun forgot to rise.', W / 2, H / 2 + 38); c.restore(); } },
    { d: 6.5, say: [null, 'Fifteen candles hold back the Hush. Every winter the Abbey snuffs them, one by one, and hides the last flame behind the altar.'],
      draw(c, t, W, H) { vgrad(c, W, H, '#0a0912', '#18101a'); moon(c, W * .74, H * .24, 38); const z = 1 + t * .02;
        c.save(); c.translate(W / 2, H * .62); c.scale(z, z); abbey(c, 0, 0, .9); c.restore(); raven(c, W * .1 + t * 120, H * .3 - t * 8, .9, t); raven(c, W * .02 + t * 110, H * .36 - t * 6, .6, t + 1); snow(c, W, H, t, 90, 1); vig(c, W, H); } },
    { d: 5.5, say: [null, 'Then the brothers strike the pews until the stones shake, and the hidden flame comes home. It always comes home.'],
      draw(c, t, W, H) { BG(c, W, H); glow(c, W / 2, H * .5, 300, '242,180,58', .18 * (1 - t / 6)); bigHearse(c, W / 2, H * .62, 3.2, Math.min(15, Math.floor(t * 3.2)), true, t); vig(c, W, H); } },
    { d: 3.6, shake: [.2, .5], say: [null, 'This winter, it did not.'],
      draw(c, t, W, H) { fill(c, W, H, '#020102'); bigHearse(c, W / 2, H * .62, 3.2, 15, t < .25, t);
        if (t > .25) sfx(c, 'GONE', W / 2, H * .3, 90, -.05, C.crimson, t - .25); } },
    { d: 2.6, flash: 'white', shake: [0, .6], say: ['???', 'Mother. I have come for the light.'],
      draw(c, t, W, H) { fill(c, W, H, '#0c0608'); focus(c, W, H, W / 2, H * .5, t, '242,220,200', .7);
        c.fillStyle = '#000'; c.fillRect(W / 2 - 110, H * .2, 220, H * .8); glow(c, W / 2, H * .55, 160, '180,77,255', .5);
        const J = rig({ x: W / 2, y: H * .9 - 80 * 2.2, f: 1, s: 2.2, lean: .02, tilt: -.05, build: { torso: 1.2, leg: 1.15, arm: 1.15, k: 1.15, head: 16 }, legs: [[-.15, -.05], [.15, -.05]], arms: [[-.2, .2], [.2, .2]] });
        paint(c, J, { body: '#000', back: '#000', rim: 'rgba(180,77,255,.95)', eyes: C.violet, glow: 20, headExtra: candleCrown(0) });
        glow(c, J.sh[0], J.sh[1] + 20, 70, '242,180,58', .55);
        sfx(c, 'KRA-KOOM', W * .78, H * .22, 70, .12, '#fff4ea', t); } },
    { d: 4.2, say: ['ABBESS HILD', 'Umber. You were the best of us. Put it back.'],
      draw(c, t, W, H) { BG(c, W, H); glow(c, W * .3, H * .5, 260, '242,180,58', .2); c.save(); c.globalAlpha = .5; bigHearse(c, W * .5, H * .3, 1.4, 15, false, t); c.restore();
        const hj = hild(c, W * .3, H * .9, 2.4, 'ready', t); blade(c, hj.armF.ex, hj.armF.ey, -.45, 'greatsword', 1.5, .8);
        c.save(); c.globalAlpha = .9; const u = rig({ x: W * .85, y: H * .9 - 80 * 2.4, f: -1, s: 2.4, lean: .05, build: { torso: 1.2, leg: 1.15, arm: 1.15, k: 1.15, head: 16 }, legs: [[-.15, -.05], [.15, -.05]], arms: [[-.2, .2], [.6, .3]] });
        paint(c, u, { body: '#000', back: '#000', rim: 'rgba(180,77,255,.9)', eyes: C.violet, headExtra: candleCrown(0) }); c.restore(); vig(c, W, H); } },
    { d: 1.6, flash: 'red', shake: [0, .6], bars: false,
      draw(c, t, W, H) { fill(c, W, H, t < .5 ? '#f3ebe0' : '#a5151b'); const col = t < .5 ? '#000' : '#000';
        hild(c, W * .38, H * .9, 2.4, 'strike', t, { sil: col }); const u = rig({ x: W * .62, y: H * .9 - 48 * 2.4, f: -1, s: 2.4, lean: .75, tilt: -.2, legs: [[-1.05, -.3], [1.05, -1.15]], arms: [[-1.7, .3], [1.75, .05]] });
        paint(c, u, { body: col, back: col, rim: false });
        c.save(); c.strokeStyle = t < .5 ? '#000' : '#fff4ea'; c.lineWidth = 10 * (1 - t / 1.6) + 2; c.beginPath(); c.moveTo(-20, H * .9); c.lineTo(W + 20, H * .1); c.stroke(); c.restore();
        sfx(c, 'ZAN', W * .5, H * .25, 120, -.15, t < .5 ? '#000' : '#fff4ea', t, t < .5 ? '#f3ebe0' : '#000'); } },
    { d: 4, say: ['SAINT UMBER', 'I carried it down every winter. This winter the dark can keep it. And me.'],
      draw(c, t, W, H) { BG(c, W, H); const x = W * .6 + t * 40;
        c.save(); c.translate(W * .08, H * .86); c.rotate(PI / 2 * .97); hild(c, 0, 0, 2, 'stand', t); c.restore();
        const u = rig({ x, y: H * .86 - 80 * 2.2, f: 1, s: 2.2, lean: .1, build: { torso: 1.2, leg: 1.15, arm: 1.15, k: 1.15, head: 16 }, legs: [[-.3, -.1], [.35, -.3]], arms: [[.2, .3], [1.1, 1.3]] });
        paint(c, u, { body: '#000', back: '#000', rim: 'rgba(180,77,255,.9)', eyes: C.violet, headExtra: candleCrown(0) });
        glow(c, u.armF.ex, u.armF.ey, 80, '242,180,58', .7); c.fillStyle = C.hot; circ(c, u.armF.ex, u.armF.ey - 6, 6);
        c.fillStyle = `rgba(0,0,0,${k01(t, 2.2, 1.6)})`; c.fillRect(0, 0, W, H); vig(c, W, H); } },
    { d: 3.4, say: [null, 'In the soot beneath the hearse, something made of old wicks opened its eyes.'],
      draw(c, t, W, H) { eyesClose(c, W, H, t, C.gold, { delay: 1.2 }); embers(c, W, H, t, 30, '242,180,58', 30); } },
    { d: 5.2, say: ['ABBESS HILD', 'I made you from burnt-out wicks, little one. You can walk where light cannot. Bring it home.'],
      draw(c, t, W, H) { BG(c, W, H); glow(c, W * .48, H * .7, 240, '242,180,58', .2);
        c.save(); c.translate(W * .16, H * .86); c.rotate(PI / 2 * .97); hild(c, 0, 0, 2, 'stand', t); c.restore();
        wick(c, W * .56, H * .86, 2, 'kneel', t, { f: -1, blade: false }); blade(c, W * .47, H * .8, -.15, 'katana', 1.6, .9 + S(t * 4) * .3); vig(c, W, H); } },
    { d: 3, flash: 'white', shake: [0, .35],
      draw(c, t, W, H) { fill(c, W, H, '#0a0507'); focus(c, W, H, W / 2, H * .5, t, '255,200,150', .6); glow(c, W / 2, H * .55, 300, '229,56,59', .35);
        wick(c, W / 2, H * .95, 3.6, 'ready', t, { wind: 1.6 }); embers(c, W, H, t, 60, '255,150,80', 160); } },
    { d: 4, bars: false, draw(c, t, W, H) { card(c, W, H, t, 4, 'WICKBEARER', 'CHAPTER I  ·  THE PIT OF PSALMS  ·  DEPTHS I-IV'); } }
  ];
  const bossIntro = (i, sfxWord, line, scene) => [
    { d: 1.9, flash: 'red', shake: [0, .8], draw(c, t, W, H) { scene(c, t, W, H); sfx(c, sfxWord, W / 2, H * .55, 130, -.08, '#fff4ea', t); } },
    { d: 1.8, draw(c, t, W, H) { eyesClose(c, W, H, t, LOOK[i].eyes || C.crimson, { slit: 1, third: 1, delay: .2, rim: LOOK[i].rim }); focus(c, W, H, W / 2, H / 2, t, '0,0,0', .7, 90, 330); } },
    { d: 3.6, say: [CH[i].boss, line], draw(c, t, W, H) { scene(c, t + 2, W, H, 1);
      drawBrute(c, W * .7, H * .96, 3.2, t * .4, -1, Object.assign({ third: 1, glow: 22, off: 0 }, LOOK[i]));
      nameCard(c, W, H, t, CH[i].who, i === 3 ? 'SAINT UMBER' : CH[i].boss.replace('THE ', '')); } }
  ];
  SC.boss0 = bossIntro(0, 'GASHAN!', 'A hundred winters I kept the Pit locked. Umber gave me a better lock. You.',
    (c, t, W, H) => { fill(c, W, H, '#070405'); chains(c, W, H, t, 12, eo(clamp(t * 2, 0, 1))); vig(c, W, H); });
  SC.end0 = [
    { d: 4, say: ['THE CHAIN WARDEN', 'He swore the chains would come off... He lied. They come off now.'],
      draw(c, t, W, H) { BG(c, W, H); chains(c, W, H, t, 8, 1 - k01(t, 1, 2)); c.save(); c.translate(0, t * 6);
        drawBrute(c, W * .55, H * .98, 2.6, 0, -1, { third: 1, glow: 10 * (1 - t / 4), eyes: C.crimson }); c.restore(); ash(c, W * .55, H * .6, t, 60, 220); vig(c, W, H); } },
    { d: 3.6, say: ['THE CHAIN WARDEN', 'Go down, wick. The Well remembers everything that drowned in it.'],
      draw(c, t, W, H) { fill(c, W, H, '#060405'); c.fillStyle = '#0d0a0c'; c.fillRect(0, H * .7, W * .58, H); c.fillStyle = '#000';
        const g = c.createLinearGradient(W * .6, 0, W, 0); g.addColorStop(0, '#000'); g.addColorStop(1, '#0b0709'); c.fillStyle = g; c.fillRect(W * .58, H * .7, W, H);
        wick(c, W * .5, H * .7, 1.6, 'look', t, { f: 1, wind: 1.6 }); glow(c, W * .8, H * 1.1, 260, '63,214,196', .14); vig(c, W, H); } },
    { d: 2.4, shake: [0, .2], draw(c, t, W, H) { fill(c, W, H, '#050304'); streaks(c, W, H, t, true, '200,190,200', .45, 80);
      c.save(); c.translate(W / 2, H * .45); c.rotate(PI); wick(c, 0, 0, 2.2, 'dive', t, { wind: .3, lift: -1.4 }); c.restore(); } },
    { d: 3, bars: false, draw(c, t, W, H) { card(c, W, H, t, 3, 'THE PIT FALLS SILENT', 'THE WARDEN IS FREE  ·  THE DESCENT GOES ON', C.gold); } }
  ];
  SC.intro1 = [
    { d: 4.4, say: [null, 'Rurik Sea-Wolf rowed his longships down the Well to plunder the dark.'],
      draw(c, t, W, H) { vgrad(c, W, H, '#03080a', '#08130f'); glow(c, W * .5, H * .3, 300, '63,214,196', .12);
        prow(c, W * .22, H * .66, 1.4, -.25); prow(c, W * .7, H * .64, 1.1, .3); prow(c, W * .48, H * .7, .8, -.05); sea(c, W, H * .66, t); raven(c, W * .8 - t * 50, H * .2, .7, t); vig(c, W, H); } },
    { d: 4, say: [null, 'The dark plundered him instead. It kept the crown. It kept the king.'],
      draw(c, t, W, H) { vgrad(c, W, H, '#041013', '#010304'); glow(c, W / 2, -40, 400, '120,220,210', .25);
        crown(c, W / 2, H * .25 + t * 40, 1.1 - t * .05, 0, t);
        c.save(); c.strokeStyle = 'rgba(160,230,220,.4)'; for (let i = 0; i < 30; i++) { c.beginPath(); c.arc(hash(i) * W, H - ((hash(i + 2) * H + t * 70) % H), 2 + hash(i + 1) * 4, 0, TAU); c.stroke(); } c.restore(); vig(c, W, H); } },
    { d: 3.6, bars: false, draw(c, t, W, H) { card(c, W, H, t, 3.6, 'THE DROWNED WELL', 'CHAPTER II  ·  DEPTHS V-VIII', C.cyan); } }
  ];
  SC.boss1 = bossIntro(1, 'DOBAAN!', 'Every king pays for his crown. I paid with my sea. What will you pay, little candle?',
    (c, t, W, H, calm) => { vgrad(c, W, H, '#03080a', '#08130f'); sea(c, W, H * .8, t);
      if (!calm) { c.fillStyle = 'rgba(170,230,220,.8)'; for (let i = 0; i < 26; i++) { const a = -PI / 2 + (hash(i) - .5) * 1.6, r = eo(clamp(t * 1.5, 0, 1)) * (200 + hash(i + 1) * 260); circ(c, W / 2 + Co(a) * r, H * .8 + S(a) * r, 4 + hash(i + 3) * 10); } } });
  SC.end1 = [
    { d: 4, say: ['THE HOLLOW KING', 'Ha... your Saint gave me this crown. Did they never tell you? He was a wick. Like you.'],
      draw(c, t, W, H) { BG(c, W, H); crown(c, W / 2, H * .45, 2, eo(k01(t, .6, 1.4)), t); vig(c, W, H); } },
    { d: 4.6, say: ['THE HOLLOW KING', 'The first she ever made. Three hundred winters he carried her light into the dark... and no one waited at the door.'],
      draw(c, t, W, H) { vgrad(c, W, H, '#2a1c12', '#140c08'); glow(c, W * .42, H * .5, 220, '242,190,120', .35);
        c.fillStyle = '#f2d9a0'; c.fillRect(W * .42 - 3, H * .5, 6, 30); glow(c, W * .42, H * .48, 40, '255,220,150', .9);
        hild(c, W * .3, H * .88, 2, 'hold', t, { sil: '#120a06' }); wick(c, W * .58, H * .88, 1.3, 'stand', t, { sil: '#120a06', blade: false });
        c.fillStyle = 'rgba(40,24,10,.35)'; c.fillRect(0, 0, W, H); vig(c, W, H, .95); } },
    { d: 2.4, flash: 'white', draw(c, t, W, H) { eyesClose(c, W, H, t + 1, C.gold, { delay: 0, sc: 1.08 }); focus(c, W, H, W / 2, H / 2, t, '242,180,58', .5, 80, 300); sfx(c, '!', W * .85, H * .3, 140, .1, C.gold, t); } },
    { d: 3, bars: false, draw(c, t, W, H) { card(c, W, H, t, 3, 'THE WELL GIVES UP ITS DEAD', 'THE FIRST WICK HAS A NAME  ·  UMBER', C.cyan); } }
  ];
  SC.intro2 = [
    { d: 4.4, say: [null, 'In the Norrow they say a jarl who dies in his bed never drinks in the Long Hall.'], draw(c, t, W, H) { forge(c, W, H, t); vig(c, W, H); } },
    { d: 4.4, say: [null, 'Jarl Sigvald found a way never to die at all. He fed himself to the forge, and the forge kept him burning.'],
      draw(c, t, W, H) { forge(c, W, H, t + 9); c.fillStyle = 'rgba(0,0,0,.35)'; c.fillRect(0, 0, W, H);
        drawBrute(c, W * .5, H * .96, 3, t * .2, 1, Object.assign({ body: '#000', back: '#000', glow: 20 }, LOOK[2])); vig(c, W, H); } },
    { d: 3.6, bars: false, draw(c, t, W, H) { card(c, W, H, t, 3.6, 'THE BLADEWORKS', 'CHAPTER III  ·  DEPTHS IX-XII', '#ff8a5c'); } }
  ];
  SC.boss2 = bossIntro(2, 'GAKIIN!', 'Umber forges me a war that never ends. Come, wick! Give me a death worth a song!', (c, t, W, H) => { forge(c, W, H, t); });
  SC.end2 = [
    { d: 3.8, say: ['THE ASHEN JARL', 'HA! Good... GOOD. That was worth a song.'],
      draw(c, t, W, H) { forge(c, W, H, t); c.save(); c.translate(W * .5, H * .96); c.rotate(-k01(t, .4, 2) * .5); drawBrute(c, 0, 0, 2.8, 0, 1, Object.assign({ glow: 18 * (1 - t / 4) }, LOOK[2])); c.restore(); ash(c, W * .5, H * .6, t, 80, 240, '255,140,70'); vig(c, W, H); } },
    { d: 4.2, say: ['THE ASHEN JARL', 'He waits on the Hollow Throne. When the last candle dies, he will wear the dark like a cloak.'],
      draw(c, t, W, H) { BG(c, W, H); bigHearse(c, W / 2, H * .62, 3.2, 12, false, t); vig(c, W, H); } },
    { d: 3, draw(c, t, W, H) { stairs(c, W, H, t); wick(c, W * .5, H * .95, 2.4, 'walk', t, { f: 1, sil: '#000', blade: false }); } },
    { d: 3, bars: false, draw(c, t, W, H) { card(c, W, H, t, 3, 'THREE CANDLES REMAIN', 'THE THRONE IS BELOW  ·  THERE IS NO WAY BACK', C.gold); } }
  ];
  SC.intro3 = [
    { d: 4.4, say: ['SAINT UMBER', 'So she made another. Of course she did.'], draw(c, t, W, H) { stairs(c, W, H, t); glow(c, W / 2, H * .3, 60, '242,180,58', .7); } },
    { d: 4.6, say: ['SAINT UMBER', 'Turn back, little brother. Down here I am the only one who still remembers what dawn looked like.'],
      draw(c, t, W, H) { fill(c, W, H, '#050207'); glow(c, W / 2, H * .5, 300, '180,77,255', .2);
        c.fillStyle = '#000'; c.fillRect(W / 2 - 180, H * .1, 360, H); c.fillStyle = '#0c0710'; c.beginPath(); c.moveTo(W / 2 - 200, H * .12); c.lineTo(W / 2, H * -.05); c.lineTo(W / 2 + 200, H * .12); c.fill();
        drawBrute(c, W / 2, H * 1.02, 3.4, 0, 1, Object.assign({ third: 1, glow: 18 }, LOOK[3], { headExtra: candleCrown(0) })); glow(c, W / 2 - 20, H * .62, 90, '242,180,58', .6); vig(c, W, H); } },
    { d: 2.4, flash: 'white', shake: [0, .25], draw(c, t, W, H) { panels(c, W, H, () => eyesClose(c, W, H, t + 1, C.gold, { delay: 0, dy: -60 }), () => eyesClose(c, W, H, t + 1, C.violet, { delay: 0, slit: 1, dy: 80, rim: 'rgba(180,77,255,.6)' })); } },
    { d: 3.8, bars: false, draw(c, t, W, H) { card(c, W, H, t, 3.8, 'THE HOLLOW THRONE', 'FINAL CHAPTER  ·  DEPTHS XIII-XVI', C.violet); } }
  ];
  SC.boss3 = [
    { d: 3.2, say: [null, 'The fifteenth candle goes out.'], draw(c, t, W, H) { fill(c, W, H, '#000'); bigHearse(c, W / 2, H * .62, 3.2, t < 1.4 ? 14 : 15, false, t);
      c.fillStyle = `rgba(0,0,0,${k01(t, 1.5, 1.2) * .9})`; c.fillRect(0, 0, W, H); c.save(); c.globalAlpha = k01(t, 2, .8); c.font = `600 22px ${SERIF}`; c.fillStyle = '#6f675f'; spaced(c, 'WICKBEARER', W / 2, H / 2, 16); c.restore(); } },
    { d: 2.6, shake: [0, 1], say: [null, 'And in the dark, the noise begins.'], draw(c, t, W, H) { fill(c, W, H, Math.floor(t * 6) % 2 ? '#2a0508' : '#000');
      sfx(c, 'DOM!', W * .25, H * .35, 110, -.15, C.crimson, t); if (t > .6) sfx(c, 'DOM!', W * .7, H * .3, 130, .12, C.crimson, t - .6); if (t > 1.2) sfx(c, 'DOM!!', W * .5, H * .68, 170, -.05, '#fff4ea', t - 1.2); } },
    { d: 2.6, draw(c, t, W, H) { fill(c, W, H, '#030105'); drawBrute(c, W / 2, H * 1.08, 4.2, 0, 1, Object.assign({ third: 1, glow: 30 }, LOOK[3], { headExtra: candleCrown(Math.floor(t * 4)) })); focus(c, W, H, W / 2, H * .3, t, '180,77,255', .35, 80, 260); } },
    { d: 3.8, say: ['SAINT UMBER', 'There is no dawn left to save. Only the dark, and the one who holds it.'], draw(c, t, W, H) { fill(c, W, H, '#050207'); glow(c, W * .7, H * .5, 300, '180,77,255', .3);
      drawBrute(c, W * .7, H * .96, 3.2, t * .4, -1, Object.assign({ third: 1, glow: 22 }, LOOK[3])); nameCard(c, W, H, t, 'THE CANDLE-EATER', 'SAINT UMBER', C.violet); } }
  ];
  SC.end3 = [
    { d: 1.8, draw(c, t, W, H) { fill(c, W, H, '#070309'); streaks(c, W, H, t, false, '220,200,255', .55, 70);
      wick(c, W * .2 + t * 160, H * .9, 2.2, 'strike', t, { wind: 1.8 }); drawBrute(c, W * .82 - t * 120, H * .95, 2.6, t, -1, Object.assign({ glow: 24 }, LOOK[3])); } },
    { d: 1.2, flash: 'white', shake: [0, .8], bars: false, draw(c, t, W, H) { fill(c, W, H, '#f3ebe0'); wick(c, W * .62, H * .9, 2.2, 'strike', t, { sil: '#000', blade: false });
      drawBrute(c, W * .4, H * .95, 2.6, 0, -1, { body: '#000', back: '#000', rim: false, headExtra: candleCrown(0) }); c.strokeStyle = '#000'; c.lineWidth = 6; c.beginPath(); c.moveTo(0, H * .55); c.lineTo(W, H * .48); c.stroke();
      sfx(c, 'ZAN!!', W / 2, H * .25, 150, -.1, '#000', t, '#f3ebe0'); } },
    { d: 3, say: [null, '...'], draw(c, t, W, H) { fill(c, W, H, '#060308'); wick(c, W * .75, H * .9, 2, 'ready', t, { f: 1, ba: .3 });
      drawBrute(c, W * .3, H * .95, 2.4, 0, -1, Object.assign({ glow: 10 }, LOOK[3]));
      if (t > 1.6) { c.strokeStyle = C.hot; c.shadowColor = C.gold; c.shadowBlur = 20; c.lineWidth = 3; const k = eo(k01(t, 1.6, .3)); c.beginPath(); c.moveTo(W * .3 - 80, H * .5 + 40); c.lineTo(W * .3 - 80 + 170 * k, H * .5 - 50 * k); c.stroke(); c.shadowBlur = 0; } } },
    { d: 4.6, say: ['SAINT UMBER', 'Every winter... I came back. Not once... was anyone waiting at the door.'], draw(c, t, W, H) { BG(c, W, H);
      c.save(); c.translate(0, 20); drawBrute(c, W * .45, H * .98, 2.4, 0, 1, Object.assign({ glow: 6 }, LOOK[3], { headExtra: candleCrown(0) })); c.restore();
      const fx = W * .5 + t * 20, fy = H * .5 - t * 18; glow(c, fx, fy, 120, '242,180,58', .8); c.fillStyle = C.hot; c.beginPath(); c.ellipse(fx, fy, 6, 12, 0, 0, TAU); c.fill(); ash(c, W * .45, H * .7, t, 70, 220); vig(c, W, H); } },
    { d: 4.6, say: [null, 'The wick took the flame into itself. A hidden candle needs someone to carry it.'], draw(c, t, W, H) { fill(c, W, H, '#050306');
      const J = wick(c, W / 2, H * .92, 2.6, 'hold', t, { blade: false, wind: .6 }); const k = k01(t, 1.2, 1.6), fx = lerp(J.armF.ex, J.sh[0], k), fy = lerp(J.armF.ey - 10, J.sh[1] + 20, k);
      glow(c, fx, fy, 100 + k * 300, '242,180,58', .7); c.fillStyle = C.hot; c.beginPath(); c.ellipse(fx, fy, 7, 13, 0, 0, TAU); c.fill(); if (t > 2.8) { c.fillStyle = `rgba(255,244,214,${k01(t, 2.8, .4) * (1 - k01(t, 3.3, 1.2))})`; c.fillRect(0, 0, W, H); } } },
    { d: 4.4, shake: [0, .3], say: [null, 'Above, the brothers struck the pews until the stones shook.'], draw(c, t, W, H) { vgrad(c, W, H, '#1a1018', '#2a1612'); glow(c, W / 2, H * .4, 300, '242,180,58', .25);
      for (let i = 0; i < 6; i++) { const x = W * (.12 + i * .15), u = Math.max(0, S(t * 7 + i)); wick(c, x, H * .9, 1.3, u > .5 ? 'strike' : 'ready', t, { sil: '#0a0608', blade: false }); }
      sfx(c, 'DOM!', W * .3, H * .3, 100, -.1, C.gold, t % .7); sfx(c, 'DOM!', W * .72, H * .26, 110, .1, C.gold, (t + .35) % .7); } },
    { d: 5.2, say: [null, 'And for the first time in three hundred winters, someone was waiting at the door.'], draw(c, t, W, H) {
      const g = c.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#2a2440'); g.addColorStop(.55, '#c0603a'); g.addColorStop(1, '#f2b45a'); c.fillStyle = g; c.fillRect(0, 0, W, H);
      glow(c, W * .5, H * .62 - t * 10, 260, '255,220,150', .8); c.fillStyle = '#fff1d0'; circ(c, W * .5, H * .66 - t * 10, 40);
      abbey(c, W * .5, H * .78, .9, 'rgba(255,230,170,.9)'); wick(c, W * .62, H * .74, 1, 'stand', t, { sil: '#120a08', blade: false }); hild(c, W * .7, H * .74, .9, 'stand', t, { sil: '#120a08' });
      raven(c, W * .9 - t * 40, H * .2, .7, t); } },
    { d: 3.6, say: [null, 'Far below, the Hush turned over in its sleep.'], draw(c, t, W, H) { fill(c, W, H, '#000'); crown(c, W / 2, H * .55, .7, .4, t);
      c.save(); c.globalAlpha = k01(t, 1.5, .4); c.fillStyle = C.violet; c.shadowColor = C.violet; c.shadowBlur = 30; c.beginPath(); c.ellipse(W / 2, H * .3, 40, 2 + 6 * k01(t, 1.8, .4), 0, 0, TAU); c.fill(); c.restore(); } },
    { d: 5, bars: false, draw(c, t, W, H) { card(c, W, H, t, 5, 'THE HIDDEN CANDLE RETURNS', 'THE END  ·  THANK YOU FOR PLAYING', C.gold, (c2, tt) => bigHearse(c2, W / 2, H * .3, 1.8, 0, true, tt)); } }
  ];
  SC.revive = [
    { d: .35, flash: 'white', bars: false, draw(c, t, W, H) { fill(c, W, H, '#f3ebe0'); wick(c, W / 2, H * .92, 2.6, 'kneel', t, { sil: '#000', blade: false }); } },
    { d: 1.7, bars: false, shake: [0, .25], draw(c, t, W, H) { fill(c, W, H, '#050203'); focus(c, W, H, W / 2, H * .5, t, '229,56,59', .45, 90, 120);
      const k = eo(k01(t, .1, .5)); glow(c, W / 2, H * .45, 60 + k * 240, '242,180,58', .9); c.fillStyle = C.hot; c.beginPath(); c.ellipse(W / 2, H * .45, 10 * k, 22 * k, 0, 0, TAU); c.fill();
      c.save(); c.globalAlpha = k01(t, .35, .3); c.font = `800 64px ${SERIF}`; c.fillStyle = C.gold; c.shadowColor = C.gold; c.shadowBlur = 24; spaced(c, 'NOT YET', W / 2, H * .8, 12); c.restore(); } }
  ];
  const ALWAYS = { revive: 1 };

  /* ---------- engine ---------- */
  function play(st, id) {
    if (!SC[id] || (seen[id] && !ALWAYS[id])) return false;
    seen[id] = 1; save(); skipAll = false; tap = false;
    st.cut = { id, i: 0, t: 0, T: 0 }; return true;
  }
  const AFTER = { end3: st => { st.victory = true; openOver(st); } };
  function finish(st) { const id = st.cut.id; st.cut = null; skipAll = false; tap = false; if (AFTER[id]) AFTER[id](st); }
  function tick(ctx, st, rdt, W, H) {
    if (st.cutPend > 0 && !st.ov && !st.cut) { if ((st.cutPend -= rdt) <= 0) { st.cutPend = 0; if (!play(st, st.cutNext) && AFTER[st.cutNext]) AFTER[st.cutNext](st); } }
    const c = st.cut; if (!c) { skipAll = false; tap = false; return false; }
    const shots = SC[c.id]; let shot = shots[c.i];
    c.t += rdt; c.T += rdt;
    const pad = (navigator.getGamepads ? [...navigator.getGamepads()] : []).find(g => g), start = pad && pad.buttons[9] && pad.buttons[9].pressed;
    if (skipAll || (start && c.T > .5)) { finish(st); return false; }
    if (c.t >= shot.d || ((PR.jump || PR.attack || tap) && c.t > .45)) { c.i++; c.t = 0; if (c.i >= shots.length) { finish(st); return false; } shot = shots[c.i]; }
    tap = false;
    const t = c.t;
    ctx.save();
    if (shot.shake) { const [a, b] = shot.shake, amt = t >= a && t < a + .5 ? b * (1 - (t - a) / .5) * 14 : 0; ctx.translate(rnd(-amt, amt), rnd(-amt, amt)); }
    shot.draw(ctx, t, W, H);
    ctx.restore();
    if (shot.flash && t < .14) { ctx.fillStyle = shot.flash === 'red' ? `rgba(229,56,59,${1 - t / .14})` : `rgba(255,248,236,${1 - t / .14})`; ctx.fillRect(0, 0, W, H); }
    else if (!shot.flash && t < .18) { ctx.fillStyle = `rgba(0,0,0,${1 - t / .18})`; ctx.fillRect(0, 0, W, H); }
    // letterbox, subtitles, controls
    const bh = shot.bars === false ? 0 : 64 * eo(clamp(c.T / .5, 0, 1));
    if (bh) { ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, bh); ctx.fillRect(0, H - bh, W, bh); }
    if (shot.say) {
      const [who, line] = shot.say, n = Math.floor(Math.max(0, t - .2) * 48), s = line.slice(0, n);
      ctx.save(); ctx.textAlign = 'center';
      if (who) { ctx.font = `600 11px ${MONO}`; ctx.fillStyle = who === 'SAINT UMBER' ? C.violet : C.gold; spaced(ctx, who, W / 2, H - 112, 4); }
      ctx.font = `${who ? 'normal' : 'italic'} 500 23px ${ITAL}`; ctx.lineWidth = 4; ctx.strokeStyle = 'rgba(0,0,0,.9)'; ctx.fillStyle = '#f3ebe0'; ctx.textAlign = 'center';
      const words = s.split(' '), lines = []; let cur = '';
      for (const w of words) { const tt = cur ? cur + ' ' + w : w; if (ctx.measureText(tt).width > 780 && cur) { lines.push(cur); cur = w; } else cur = tt; }
      lines.push(cur); const y0 = H - 82 + (lines.length > 1 ? -10 : 0);
      lines.forEach((l, i) => { ctx.strokeText(l, W / 2, y0 + i * 26); ctx.fillText(l, W / 2, y0 + i * 26); });
      ctx.restore();
    }
    ctx.save(); ctx.font = `600 10px ${MONO}`; ctx.textAlign = 'right'; ctx.fillStyle = 'rgba(160,150,140,.75)'; ctx.fillText('J / CLICK  NEXT     ESC  SKIP', W - 16, 22); ctx.restore();
    return true;
  }

  /* ---------- hooks the game calls ---------- */
  function onRun(st) {
    st.cut = null; st.cutPend = 0; st.victory = false;
    const chq = parseInt(q.get('chapter') || '0', 10), fin = q.has('final');
    if (!jumpUsed && (chq > 1 || fin)) {
      jumpUsed = true; const i = fin ? 3 : clamp(chq, 1, 4) - 1;
      Object.assign(st, { depth: fin ? 15 : CH[i].from, nextBoss: fin ? 16 : CH[i].from + 3, bosses: i, lvl: 1 + i * 4, temper: i, hp: 5 });
      if (fin) st.dp = DEPTH_T - 2;
      if (!fin) { seen['intro' + i] = 0; play(st, 'intro' + i); }
      return;
    }
    play(st, 'prologue');
  }
  function onDepth(st) { const i = chOf(st.depth); if (st.depth === CH[i].from && i > 0) play(st, 'intro' + i); }
  function bossIntro_(st) { const i = chOf(st.depth); play(st, 'boss' + i); return i === 3 ? 'SAINT UMBER, THE CANDLE-EATER' : CH[i].boss; }
  function onBossSpawn(st) {
    const b = st.boss, i = chOf(st.depth); b.look = i; b.king = i === 1 || i === 3;
    if (i === 2) b.hp *= 1.25; if (i === 3) { b.hp *= 2.2; b.final = 1; } b.mhp = b.hp;
  }
  function onBossSlain(st) {
    const i = chOf(st.depth); st.cutPend = 1.4; st.cutNext = 'end' + i;
    if (i === 3) { st.pendShop = 0; st.pendDraft = 0; st.banner = { text: 'SAINT UMBER FALLS', sub: 'THE HIDDEN CANDLE IS FREE', t: 2.4, col: C.gold }; }
    else st.banner = { text: `${CH[i].boss.replace('THE ', '')} SLAIN`, sub: `CHAPTER ${CH[i].n} COMPLETE  ·  ${CH[i + 1].name} AWAITS BELOW`, t: 2.4, col: C.gold };
  }
  const bossLook = e => LOOK[e.look ?? (e.king ? 1 : 0)];
  const place = st => { const i = chOf(st.depth); return `CHAPTER ${CH[i].n} · ${CH[i].name}`; };
  const candlesOut = d => clamp(d - 1, 0, 15);

  /* ---------- souls-like death ---------- */
  const el = st => DEATH_T - st.dying;
  function deathPose(st, p) {
    const e = el(st), f = p.f, y = p.y;
    if (e >= 2.1 && e < 3.3) for (let i = 0; i < 4; i++) emit(st.P, { x: p.x + rnd(-14, 14), y: y - rnd(4, 52), vx: rnd(-20, 50), vy: rnd(-110, -30), drag: .6, r: rnd(1.4, 3.2),
      col: Math.random() < .25 ? C.gold : Math.random() < .5 ? '#4a3c38' : '#1c1416', glow: 0, life: rnd(1.2, 2.4), shrink: 1 });
    if (e < .55) { const k = eo(e / .55); return { pose: { lean: -.35 * k, tilt: -.6 * k, legs: [[-.25, -.2], [.3, -.35]], arms: [[-.9 * k, .3], [-.7 * k, .2]] }, hip: y - 40, bladeAng: f > 0 ? -.4 - k * .6 : PI + .4 + k * .6 }; }
    const k = eo(clamp((e - .55) / .55, 0, 1)), sag = clamp((e - 1.1) / 1, 0, 1);
    return { pose: { lean: lerp(-.35, .4, k) + sag * .1, tilt: lerp(-.6, .65, k) + sag * .25, legs: [[lerp(-.25, -.05, k), lerp(-.2, -1.5, k)], [lerp(.3, 1.45, k), lerp(-.35, -1.45, k)]], arms: [[lerp(-.9, .3, k), .3], [lerp(-.7, .75, k), .4]] },
      hip: y - lerp(40, 24, k), bladeAng: k < 1 ? (f > 0 ? lerp(-1, PI / 2 - .1, k) : lerp(PI + 1, PI / 2 + .1, k)) : (f > 0 ? PI / 2 - .1 : PI / 2 + .1) };
  }
  const deathAlpha = st => { const e = el(st); return e < 2.1 ? 1 : clamp(1 - (e - 2.1) / 1.1, 0, 1); };
  function deathDim(ctx, st, W, H) {
    const e = el(st);
    ctx.save(); ctx.globalCompositeOperation = 'saturation'; ctx.fillStyle = `rgba(128,128,128,${clamp(e / 1.4, 0, 1) * .9})`; ctx.fillRect(0, 0, W, H); ctx.restore();
    ctx.fillStyle = `rgba(0,0,0,${clamp(e / 3, 0, 1) * .5})`; ctx.fillRect(0, 0, W, H);
    if (e < .2) { ctx.fillStyle = `rgba(229,56,59,${.6 * (1 - e / .2)})`; ctx.fillRect(0, 0, W, H); }
  }
  function drawDeath(ctx, st, W, H) {
    const e = el(st); if (e < 2.4) return;
    const a = clamp((e - 2.4) / 1.3, 0, 1), out = clamp(st.dying / .45, 0, 1);
    ctx.save(); ctx.fillStyle = `rgba(0,0,0,${.5 * a})`; ctx.fillRect(0, 0, W, H);
    const g = ctx.createLinearGradient(0, 0, W, 0); g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(.2, `rgba(0,0,0,${.85 * a})`); g.addColorStop(.8, `rgba(0,0,0,${.85 * a})`); g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g; ctx.fillRect(0, H / 2 - 62, W, 124);
    const sc = 1 + (e - 2.4) * .022; ctx.translate(W / 2, H / 2 + 20); ctx.scale(sc, sc); ctx.globalAlpha = a * out;
    ctx.font = `600 66px ${SERIF}`; ctx.fillStyle = '#9e1419'; ctx.shadowColor = 'rgba(229,56,59,.55)'; ctx.shadowBlur = 34; spaced(ctx, 'EXTINGUISHED', 0, 0, 12);
    ctx.restore();
    ctx.save(); ctx.globalAlpha = k01(e, 3.4, 1) * out; ctx.font = `italic 500 21px ${ITAL}`; ctx.fillStyle = '#b3a79d'; ctx.textAlign = 'center';
    ctx.fillText('The dark keeps what it takes.', W / 2, H / 2 + 58); ctx.restore();
  }

  return { DEATH_T, tick, onRun, onDepth, bossIntro: bossIntro_, onBossSpawn, onBossSlain, bossLook, place, candlesOut, onRevive: st => play(st, 'revive'),
    deathPose, deathAlpha, deathDim, drawDeath, chOf };
})();
