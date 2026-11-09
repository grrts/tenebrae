/* ===================== META: progress that outlives the run (the Reliquary) =====================
   Injected by build_meta.py into the playtest build, inside the same scope as the game.
   Banked ash is spent between runs on Blessings (ranked, permanent stat boosts) and Relics
   (one-time unlocks). Beating a chapter boss lights its Waystone: later runs can start at that
   chapter. Everything is saved in localStorage ('wickbearer.meta'); ?fresh wipes it.
   The numbers match RunData.BLESSINGS in the Godot build (src/run_data.gd). */
const META = (() => {
  const KEY = 'wickbearer.meta', q = new URLSearchParams(location.search);
  if (q.has('fresh')) try { localStorage.removeItem(KEY); } catch (e) {}
  // id, name, ranks, base cost, text for a rank. The next rank costs base * (1 + 0.75 * rank).
  const BLESS = [
    { id: 'might', name: 'MIGHT', max: 5, cost: 80, d: r => `All damage +${r * 10}%.` },
    { id: 'vital', name: 'VITALITY', max: 3, cost: 110, d: r => `+${r * 20} max HP.` },
    { id: 'mend', name: 'RECOVERY', max: 3, cost: 100, d: r => `Restore 20 HP every ${[0, 40, 30, 20][r]} kills.` },
    { id: 'swift', name: 'SWIFTNESS', max: 3, cost: 70, d: r => `Move ${r * 7}% faster.` },
    { id: 'fleet', name: 'FLEETFOOT', max: 2, cost: 90, d: r => `Dash cooldown -${r * 15}%.` },
    { id: 'growth', name: 'GROWTH', max: 3, cost: 90, d: r => `Levels need ${r * 10}% less ash: more runes.` },
    { id: 'greed', name: 'GREED', max: 4, cost: 70, d: r => `Every ash pickup is worth ${r * 15}% more.` },
    { id: 'keep', name: 'KEEPSAKE', max: 3, cost: 90, d: r => `Keep ${40 + r * 10}% of your ash when you die.` },
    { id: 'spare', name: 'SPARE CANDLE', max: 1, cost: 600, d: r => r ? 'The hidden candle brings you back twice.' : 'The hidden candle brings you back once.' },
  ];
  const RELICS = [
    { id: 'sickle', name: 'CHAIN SICKLE', kind: 'WEAPON', cost: 250, d: 'Adds the chain sickle to the weapon draw.' },
    { id: 'veil', name: 'IRON VEIL', kind: 'RUNE', cost: 200, d: 'Adds the rune to the draft pool: block a hit every 10 s.' },
    { id: 'draw3', name: 'SECOND DRAW', kind: 'PERK', cost: 180, d: 'The weapon draw offers three weapons.' },
    { id: 'flask', name: 'EMBER FLASK', kind: 'PERK', cost: 200, d: 'Restore 20 HP after every boss.' },
    { id: 'rune0', name: 'SPARE RUNE', kind: 'PERK', cost: 300, d: 'Draft one free rune at the start of every run.' },
  ];
  const CHS = [['I', 'THE PIT OF PSALMS', 1, ''], ['II', 'THE DROWNED WELL', 5, 'THE CHAIN WARDEN'], ['III', 'THE BLADEWORKS', 9, 'THE HOLLOW KING'], ['IV', 'THE HOLLOW THRONE', 13, 'THE ASHEN JARL']];
  const price = (b, r) => Math.round(b.cost * (1 + .75 * r) / 5) * 5;
  const paid = (b, r) => { let s = 0; for (let i = 0; i < r; i++) s += price(b, i); return s; };

  let SV = null;
  function load() {
    let d = {}; try { d = JSON.parse(localStorage.getItem(KEY) || '{}') || {}; } catch (e) { d = {}; }
    SV = Object.assign({ v: 1, ash: 0, best: 0, runs: 0, dawns: 0, way: 0, start: 0, well: false, ranks: {}, own: {} }, d);
    SV.ranks = SV.ranks || {}; SV.own = SV.own || {};
    return SV;
  }
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(SV)); } catch (e) {} };
  const rank = id => SV.ranks[id] || 0;

  /* ---------- a run starts: apply everything that was bought ---------- */
  function begin(st) {
    const m = st.meta = SV;
    st.baseHp = 5 + rank('vital'); st.maxHp = st.hp = st.baseHp;
    st.mods = { dmg: 1 + rank('might') * .1, spd: 1 + rank('swift') * .07, dash: 1 - rank('fleet') * .15, xp: 1 - rank('growth') * .1, ash: 1 + rank('greed') * .15 };
    st.regenN = [0, 40, 30, 20][rank('mend')]; st.regenK = 0; st.ashFrac = 0;
    st.spare = rank('spare'); st.freeDrafts = m.own.rune0 ? 1 : 0; st.startBosses = 0;
    // a lit waystone: start at a later chapter, with the levels and temper a run would have by then
    const i = Math.min(m.start || 0, m.way || 0);
    if (i > 0) {
      Object.assign(st, { depth: CHS[i][2], nextBoss: CHS[i][2] + 3, bosses: i, lvl: 1 + i * 3, temper: i, dp: 0 });
      st.startBosses = i; st.freeDrafts += i * 2; STORY.onDepth(st);
    }
  }
  function weaponDraw(st, pool) {
    const a = pool.slice(), out = [];
    while (out.length < (SV.own.draw3 ? 3 : 2) && a.length) out.push(a.splice(Math.floor(st.rng() * a.length), 1)[0]);
    return out;
  }
  function ash(st, n) { const v = n * st.mods.ash + st.ashFrac, w = Math.floor(v); st.ashFrac = v - w; return w; }
  function onKill(st, e) {
    const p = st.p, heal = n => { if (has(st, 'HUNGER') || st.hp >= st.maxHp) return; st.hp = Math.min(st.maxHp, st.hp + n); st.N.push({ x: p.x, y: p.y - 80, v: `+${n * 20} HP`, life: 1, crit: true, col: C.crimson }); };
    if (st.regenN && ++st.regenK >= st.regenN) { st.regenK = 0; heal(1); }
    if (e.type === 'boss') {
      const i = Math.min(3, Math.floor((st.depth - 1) / 4));
      if (i < 3 && SV.way < i + 1) { SV.way = i + 1; SV.start = i + 1; st.newWay = i + 1; save(); }
      if (SV.own.flask) heal(1);
    }
  }

  /* ---------- the run ends: bank the ash ---------- */
  function over(st) {
    const keep = .4 + rank('keep') * .1, bosses = st.bosses - (st.startBosses || 0);
    const kept = st.victory ? st.runWax + bosses * 50 : Math.round(st.runWax * keep) + bosses * 50;
    const from = SV.ash; SV.ash += kept; SV.runs++; if (st.victory) SV.dawns++;
    const newBest = st.depth > SV.best; SV.best = Math.max(SV.best, st.depth); save();
    st.ov = { kind: 'over', t: 0, dur: 30, victory: !!st.victory, run: st.run, seed: st.seed, depth: st.depth, best: SV.best, newBest, time: st.rt, bosses: st.bosses, kills: st.kills,
      wax: st.runWax, kept, keep, from, bank: SV.ash, way: st.newWay || 0, arena: st.arenaNow, build: [st.weapon].concat(st.runes) };
  }
  // cheapest thing still to buy
  function nextGoal() {
    let best = null;
    for (const b of BLESS) if (rank(b.id) < b.max) { const c = price(b, rank(b.id)); if (!best || c < best[1]) best = [b.name + (b.max > 1 ? ' ' + roman(rank(b.id) + 1) : ''), c]; }
    for (const r of RELICS) if (!SV.own[r.id]) { if (!best || r.cost < best[1]) best = [r.name, r.cost]; }
    return best;
  }
  function summary(ctx, st, W, H, txt, t) {
    const o = st.ov, ki = clamp((t - 1.2) / .8, 0, 1);
    txt(`ASH COLLECTED  ${o.wax}`, W / 2 - 20, 336, `600 13px ${MONO}`, '#f3ebe0', 'right', 3);
    txt(`${o.victory ? 'ALL' : Math.round(o.keep * 100) + '%'} KEPT${o.bosses ? ' + BOSS BONUS' : ''}  +${Math.round(o.kept * ki)}`, W / 2 + 20, 336, `600 13px ${MONO}`, C.cyan, 'left', 3);
    const bk = easeOut(clamp((t - 1.8) / 1, 0, 1)), bank = Math.round(lerp(o.from, o.bank, bk));
    txt(`◆ ${bank} ASH IN THE RELIQUARY`, W / 2, 384, `900 30px ${DISP}`, C.gold, 'center', 5);
    const g = nextGoal();
    if (g && t > 2.6) { const ok = o.bank >= g[1];
      txt(ok ? `YOU CAN BUY ${g[0]} (◆ ${g[1]}) · YOUR NEXT RUN STARTS STRONGER` : `NEXT: ${g[0]} AT ◆ ${g[1]} · ${g[1] - o.bank} TO GO`, W / 2, 410, `600 12px ${MONO}`, ok ? C.cyan : '#9a9289', 'center', 3); }
    if (o.way && t > 3.1) { const k = easeOut(clamp((t - 3.1) * 4, 0, 1)); ctx.save(); ctx.translate(W / 2, 452); ctx.scale(1.5 - k * .5, 1.5 - k * .5); ctx.globalAlpha *= k;
      ctx.shadowColor = C.gold; ctx.shadowBlur = 24; txt(`WAYSTONE LIT · CHAPTER ${CHS[o.way][0]}`, 0, 0, `900 30px ${DISP}`, C.gold, 'center', 5); ctx.restore();
      txt(`YOUR NEXT RUN CAN START AT ${CHS[o.way][1]}`, W / 2, 476, `600 11px ${MONO}`, '#9a9289', 'center', 3); }
  }

  /* ---------- the Reliquary screen ---------- */
  // column 0: blessings. column 1: relics, then the waystone, refund and descend rows.
  const C1 = RELICS.length, ROW_WAY = C1, ROW_REF = C1 + 1, ROW_GO = C1 + 2;
  let rects = [], lastW = 960, lastH = 600, cv = null;
  function open(st, fromDraw) {
    st.dying = 0; st.banner = null;
    st.ov = { kind: 'relic', t: 0, col: 1, row: ROW_GO, pick: 0, flash: null, msg: null, refund: 0, fromDraw: !!fromDraw };
    sync(st.ov);
  }
  const sync = o => { o.pick = o.col * 100 + o.row; };
  function close(st) { save(); st.ov = null; newRun(st); }
  function say(o, s, col) { o.msg = { s, col: col || '#e6ddd2', t: 2.2 }; }
  function act(st, o) {
    if (o.col === 0) {
      const b = BLESS[o.row], r = rank(b.id);
      if (r >= b.max) { say(o, `${b.name} IS AT ITS LAST RANK`); AUDIO.play('uiLeave'); return; }
      const c = price(b, r);
      if (SV.ash < c) { say(o, `NEED ◆ ${c - SV.ash} MORE ASH FOR ${b.name}`, C.crimson); AUDIO.play('uiLeave'); return; }
      SV.ash -= c; SV.ranks[b.id] = r + 1; save(); o.flash = { k: 'b' + o.row, t: .6 }; AUDIO.play('uiOk');
      say(o, `${b.name} ${roman(r + 1)} · ${b.d(r + 1).toUpperCase()}`, C.gold); return;
    }
    if (o.row < C1) {
      const u = RELICS[o.row];
      if (SV.own[u.id]) { say(o, `${u.name} IS ALREADY YOURS`); return; }
      if (SV.ash < u.cost) { say(o, `NEED ◆ ${u.cost - SV.ash} MORE ASH FOR ${u.name}`, C.crimson); AUDIO.play('uiLeave'); return; }
      SV.ash -= u.cost; SV.own[u.id] = 1; save(); o.flash = { k: 'r' + o.row, t: .6 }; AUDIO.play('uiOk'); say(o, `${u.name} UNLOCKED`, C.gold); return;
    }
    if (o.row === ROW_WAY) { turnWay(o, 1); return; }
    if (o.row === ROW_REF) {
      const back = BLESS.reduce((s, b) => s + paid(b, rank(b.id)), 0);
      if (!back) { say(o, 'NO BLESSINGS TO REFUND'); return; }
      if (!o.refund) { o.refund = 3; say(o, `PRESS AGAIN TO REFUND ALL BLESSINGS FOR ◆ ${back}`, C.crimson); return; }
      SV.ash += back; SV.ranks = {}; o.refund = 0; save(); AUDIO.play('uiLeave'); say(o, `REFUNDED ◆ ${back} · RELICS STAY`, C.cyan); return;
    }
    close(st);
  }
  function turnWay(o, d) {
    if (!SV.way) { say(o, 'SLAY THE CHAIN WARDEN TO LIGHT THE FIRST WAYSTONE'); AUDIO.play('uiLeave'); return; }
    SV.start = ((SV.start || 0) + d + SV.way + 1) % (SV.way + 1); save(); AUDIO.play('uiMove');
  }
  function step(st, rdt) {
    const o = st.ov; o.t += rdt;
    if (o.flash && (o.flash.t -= rdt) <= 0) o.flash = null;
    if (o.msg && (o.msg.t -= rdt) <= 0) o.msg = null;
    if (o.refund > 0) o.refund = Math.max(0, o.refund - rdt);
    if (o.t < .3) return;
    const n = o.col ? ROW_GO + 1 : BLESS.length;
    if (PR.up) { o.row = (o.row + n - 1) % n; o.refund = 0; }
    if (PR.down) { o.row = (o.row + 1) % n; o.refund = 0; }
    if (o.col === 1 && o.row === ROW_WAY && (PR.left || PR.right)) turnWay(o, PR.left ? -1 : 1);
    else if (PR.left || PR.right) { o.col = 1 - o.col; o.row = Math.min(o.row, (o.col ? ROW_GO + 1 : BLESS.length) - 1); o.refund = 0; }
    if (mouse.moved) { mouse.moved = false; const h = rects.find(r => mouse.x >= r.x && mouse.x <= r.x + r.w && mouse.y >= r.y && mouse.y <= r.y + r.h); if (h) { o.col = h.col; o.row = h.row; } }
    if (PR.ok) act(st, o);
    else if (PR.back || PR.dash) close(st);
    if (st.ov === o) sync(o);
  }
  const mouse = { x: 0, y: 0, moved: false };
  addEventListener('mousemove', e => {
    cv = cv || document.getElementById('cv-demo'); if (!cv) return; const b = cv.getBoundingClientRect();
    mouse.x = (e.clientX - b.left) / b.width * lastW; mouse.y = (e.clientY - b.top) / b.height * lastH; mouse.moved = true;
  });

  function pips(ctx, x, y, n, of, col) { for (let k = 0; k < of; k++) diamond(ctx, x + k * 17, y, 6, k < n ? col : 'rgba(255,255,255,.14)', null); }
  function row(ctx, txt, o, col, r, x, y, w, h, sel, flash) {
    rects.push({ col, row: r, x, y, w, h });
    rrect(ctx, x, y, w, h, 7); ctx.fillStyle = sel ? '#24192a' : 'rgba(18,13,20,.85)'; if (sel) { ctx.shadowColor = C.gold; ctx.shadowBlur = 18; } ctx.fill(); ctx.shadowBlur = 0;
    ctx.strokeStyle = flash || sel ? C.gold : 'rgba(255,255,255,.1)'; ctx.lineWidth = sel || flash ? 2.5 : 1; ctx.stroke();
    if (flash) { ctx.save(); ctx.globalAlpha *= flash; ctx.fillStyle = 'rgba(242,180,58,.25)'; ctx.fill(); ctx.restore(); }
  }
  // what the selected row does, in full, for the strip under the lists
  function detail(o) {
    if (o.col === 0) { const b = BLESS[o.row], r = rank(b.id);
      return [b.name + (r ? ` ${roman(r)}` : ''), r >= b.max ? `${b.d(r)}  ·  FULLY UPGRADED` : r ? `Now: ${b.d(r)}   Next: ${b.d(r + 1)}` : b.d(1)]; }
    if (o.row < C1) { const u = RELICS[o.row]; return [`${u.name} · ${u.kind}`, u.d]; }
    if (o.row === ROW_WAY) return ['WAYSTONE', SV.way ? 'Pick the chapter your next run starts in. Later chapters give you the levels and free runes you skipped.' : 'Slay the Chain Warden once to start future runs at Chapter II.'];
    if (o.row === ROW_REF) return ['REFUND', 'Get back all the ash spent on Blessings to buy a different set. Relics stay yours.'];
    return ['DESCEND', 'Start the next run with everything you bought.'];
  }
  function draw(ctx, st, W, H, txt) {
    const o = st.ov, t = o.t, fade = clamp(t * 5, 0, 1); lastW = W; lastH = H; rects = [];
    ctx.save(); ctx.globalAlpha = fade; ctx.fillStyle = '#050304'; ctx.fillRect(0, 0, W, H); ctx.globalAlpha = fade;
    ctx.shadowColor = C.gold; ctx.shadowBlur = 20; txt('THE RELIQUARY', W / 2 - 110, 52, `900 46px ${DISP}`, '#f3ebe0', 'center', 6); ctx.shadowBlur = 0;
    txt(`◆ ${SV.ash} ASH`, W / 2 + 130, 52, `900 34px ${DISP}`, C.gold, 'left', 5);
    txt(`RUNS ${SV.runs} · DEEPEST ${SV.best ? roman(SV.best) : '-'} · DAWNS ${SV.dawns}`, W / 2, 80, `600 13px ${MONO}`, '#8a827a', 'center', 3);
    const gx = 18, cw = (W - gx * 3) / 2, y0 = 116, rh = 40, gap = 4, x1 = gx * 2 + cw;
    txt('BLESSINGS · STAT UPGRADES', gx + 2, y0 - 9, `600 13px ${MONO}`, C.gold, 'left', 3);
    txt('RELICS · UNLOCKS', x1 + 2, y0 - 9, `600 13px ${MONO}`, C.cyan, 'left', 3);
    BLESS.forEach((b, i) => {
      const y = y0 + i * (rh + gap), r = rank(b.id), sel = o.col === 0 && o.row === i, mx = r >= b.max, c = mx ? 0 : price(b, r), ok = !mx && SV.ash >= c;
      row(ctx, txt, o, 0, i, gx, y, cw, rh, sel, o.flash && o.flash.k === 'b' + i ? o.flash.t / .6 : 0);
      txt(b.name, gx + 14, y + 29, `900 24px ${DISP}`, sel || r ? '#f3ebe0' : '#c9bfb4', 'left', 4); pips(ctx, gx + 196, y + 20, r, b.max, C.gold);
      txt(mx ? 'MAX' : `◆ ${c}`, gx + cw - 14, y + 29, `900 24px ${DISP}`, mx ? C.cyan : ok ? C.gold : '#6a625b', 'right', 4);
    });
    RELICS.forEach((u, i) => {
      const y = y0 + i * (rh + gap), sel = o.col === 1 && o.row === i, own = SV.own[u.id], ok = SV.ash >= u.cost;
      row(ctx, txt, o, 1, i, x1, y, cw, rh, sel, o.flash && o.flash.k === 'r' + i ? o.flash.t / .6 : 0);
      txt(u.name, x1 + 14, y + 29, `900 24px ${DISP}`, sel || own ? '#f3ebe0' : '#c9bfb4', 'left', 4);
      txt(u.kind, x1 + 214, y + 26, `600 12px ${MONO}`, u.kind === 'WEAPON' ? C.gold : u.kind === 'RUNE' ? C.cyan : C.crimson, 'left', 3);
      txt(own ? 'OWNED' : `◆ ${u.cost}`, x1 + cw - 14, y + 29, `900 24px ${DISP}`, own ? C.cyan : ok ? C.gold : '#6a625b', 'right', 4);
    });
    // waystone
    let y = y0 + ROW_WAY * (rh + gap) + 8, sel = o.col === 1 && o.row === ROW_WAY;
    const si = Math.min(SV.start || 0, SV.way || 0), ch = CHS[si];
    row(ctx, txt, o, 1, ROW_WAY, x1, y, cw, 52, sel, 0);
    txt('START AT', x1 + 14, y + 21, `600 12px ${MONO}`, '#9a9289', 'left', 3);
    txt(`‹ CH. ${ch[0]} · ${ch[1]} ›`, x1 + cw - 14, y + 23, `900 22px ${DISP}`, SV.way ? '#f3ebe0' : '#6a625b', 'right', 4);
    txt(SV.way < 3 ? `WAYSTONES ${SV.way}/3 · SLAY ${CHS[SV.way + 1][3]} FOR THE NEXT` : 'EVERY WAYSTONE IS LIT', x1 + 14, y + 43, `600 11px ${MONO}`, '#8a827a', 'left', 3);
    // refund
    y += 52 + gap; sel = o.col === 1 && o.row === ROW_REF;
    row(ctx, txt, o, 1, ROW_REF, x1, y, cw, 34, sel, 0);
    const back = BLESS.reduce((s, b) => s + paid(b, rank(b.id)), 0);
    txt(o.refund ? `PRESS AGAIN: REFUND ◆ ${back}` : `REFUND BLESSINGS  ·  ◆ ${back} BACK`, x1 + cw / 2, y + 23, `600 14px ${MONO}`, o.refund ? C.crimson : '#b0a79e', 'center', 3);
    // descend
    y += 34 + gap * 2; sel = o.col === 1 && o.row === ROW_GO;
    const dh = y0 + 9 * (rh + gap) - gap - y;
    rects.push({ col: 1, row: ROW_GO, x: x1, y, w: cw, h: dh });
    rrect(ctx, x1, y, cw, dh, 8); ctx.fillStyle = sel ? '#3a0d12' : '#1a0a0d'; if (sel) { ctx.shadowColor = C.crimson; ctx.shadowBlur = 22 + S(t * 6) * 6; } ctx.fill(); ctx.shadowBlur = 0;
    ctx.strokeStyle = C.crimson; ctx.lineWidth = sel ? 3 : 1.4; ctx.stroke();
    txt(si ? `DESCEND · CHAPTER ${ch[0]}` : 'DESCEND', x1 + cw / 2, y + dh / 2 + 12, `900 34px ${DISP}`, '#f3ebe0', 'center', 5);
    // the selected row, in words
    const dy = y0 + 9 * (rh + gap) + 4, [dn, dd] = detail(o);
    rrect(ctx, gx, dy, W - gx * 2, 54, 8); ctx.fillStyle = 'rgba(242,180,58,.07)'; ctx.fill();
    if (o.msg) txt(o.msg.s, W / 2, dy + 34, `700 18px ${MONO}`, o.msg.col, 'center', 4);
    else { txt(dn, gx + 16, dy + 22, `900 20px ${DISP}`, C.gold, 'left', 4); txt(dd, gx + 16, dy + 44, `500 17px ${BODY}`, '#e6ddd2', 'left', 4); }
    txt(`ARROWS  CHOOSE     ENTER / ${keyLabel('attack')}  BUY     ${keyLabel('dash')}  DESCEND`, W / 2, H - 8, `600 13px ${MONO}`, '#8a827a', 'center', 3);
    ctx.restore();
  }
  return { load, begin, weaponDraw, ash, onKill, over, summary, open, step, draw, BLESS, RELICS, price, get save() { return SV; }, persist: save };
})();
window.META = META;
