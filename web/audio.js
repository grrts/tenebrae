/* ===================== AUDIO: procedural sound design, dark ambient score, gibberish voices =====================
   Injected by build_audio.py into the playtest build, inside the same scope as the game and STORY.
   Every sound is synthesized live with the Web Audio API: no samples, nothing licensed, all original.
   The game is not changed: AUDIO.watch(st) runs once per frame, compares the state with the last frame
   and plays what changed (hits, kills, jumps, candles, bosses, menus, cutscene shots, the death).
   M toggles sound (remembered). ?mute starts muted. AUDIO.log holds the last events (for tests). */
const AUDIO = (() => {
  const q = new URLSearchParams(location.search);
  const ls = (k, v) => { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } };
  const cl = (v, a, b) => Math.max(a, Math.min(b, v)), mix = (a, b, k) => a + (b - a) * k, R = (a, b) => a + Math.random() * (b - a);
  const mf = m => 440 * Math.pow(2, (m - 69) / 12);
  let ac = null, out, comp, revIn, sfxB, musB, musF, ambB, voxB, driveB, duckG, noiseBuf, muted = ls('tenebrae.mute') === '1' || q.has('mute');
  const log = [], logE = n => { log.push(n); if (log.length > 400) log.shift(); };
  let toast = 0;

  /* ---------- setup (on the first key, click or tap; browsers keep audio locked until then) ---------- */
  function impulse(sec, decay) {
    const n = Math.floor(ac.sampleRate * sec), b = ac.createBuffer(2, n, ac.sampleRate);
    for (let c = 0; c < 2; c++) { const d = b.getChannelData(c); let lp = 0;
      for (let i = 0; i < n; i++) { const k = i / n; lp = lp * (.35 + k * .6) + (Math.random() * 2 - 1) * (1 - (.35 + k * .6)); d[i] = lp * Math.pow(1 - k, decay) * (i < 40 ? i / 40 : 1); } }
    return b;
  }
  function bus(g, send) {
    const b = ac.createGain(); b.gain.value = g; b.connect(out);
    if (send) { const s = ac.createGain(); s.gain.value = send; b.connect(s); s.connect(revIn); }
    return b;
  }
  function init() {
    if (ac) { if (ac.state === 'suspended') ac.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
    try { ac = new AC(); } catch (e) { ac = null; return; }
    graph();
    startMusic();
    if (ac.state === 'suspended') ac.resume();
  }
  function graph() {
    comp = ac.createDynamicsCompressor(); comp.threshold.value = -12; comp.knee.value = 6; comp.ratio.value = 4; comp.attack.value = .012; comp.release.value = .18;
    const clip = ac.createWaveShaper(), cv = new Float32Array(2048); for (let i = 0; i < 2048; i++) { const x = i / 1023.5 - 1; cv[i] = Math.tanh(x * 1.6) / Math.tanh(1.6); }
    clip.curve = cv; clip.oversample = '4x';
    out = ac.createGain(); out.gain.value = muted ? 0 : .75; out.connect(comp); comp.connect(clip); clip.connect(ac.destination);
    const rev = ac.createConvolver(); rev.buffer = impulse(4.6, 2.4); revIn = ac.createGain(); revIn.connect(rev);
    const rg = ac.createGain(); rg.gain.value = .6; rev.connect(rg); rg.connect(out);
    const nb = ac.sampleRate * 3; noiseBuf = ac.createBuffer(1, nb, ac.sampleRate); const nd = noiseBuf.getChannelData(0); for (let i = 0; i < nb; i++) nd[i] = Math.random() * 2 - 1;
    sfxB = bus(1.35, .13); ambB = bus(.4, .4); voxB = bus(1, .26);
    // drive: saturated layers for crunch and weight
    const ws = ac.createWaveShaper(), dc = new Float32Array(2048); for (let i = 0; i < 2048; i++) { const x = i / 1023.5 - 1; dc[i] = Math.tanh(x * 5); }
    ws.curve = dc; ws.oversample = '2x'; driveB = ac.createGain(); driveB.connect(ws); const dg = ac.createGain(); dg.gain.value = .55; ws.connect(dg); dg.connect(sfxB);
    musF = ac.createBiquadFilter(); musF.type = 'lowpass'; musF.frequency.value = 16000; musF.Q.value = .5;
    musB = ac.createGain(); musB.gain.value = 0; duckG = ac.createGain(); musB.connect(musF); musF.connect(duckG); duckG.connect(out);
    const ms = ac.createGain(); ms.gain.value = .3; duckG.connect(ms); ms.connect(revIn);
  }
  addEventListener('keydown', e => {
    init();
    if (e.code === 'KeyM' && !e.repeat) { muted = !muted; ls('tenebrae.mute', muted ? '1' : '0'); toast = 1.6; if (ac) out.gain.setTargetAtTime(muted ? 0 : .75, ac.currentTime, .05); }
  }, true);
  addEventListener('pointerdown', init, true);
  addEventListener('touchstart', init, true);

  /* ---------- synthesis kit ---------- */
  let tOff = 0;
  const now = () => ac.currentTime + tOff;
  function voice(s, t, d, o) {
    let n = s;
    if (o.ft) { const f = ac.createBiquadFilter(); f.type = o.ft; f.frequency.setValueAtTime(o.ff, t); if (o.ff2) f.frequency.exponentialRampToValueAtTime(o.ff2, t + (o.fg || d)); f.Q.value = o.q ?? 1; n.connect(f); n = f; }
    if (o.ft2) { const f = ac.createBiquadFilter(); f.type = o.ft2; f.frequency.value = o.ff3; f.Q.value = o.q2 ?? .7; n.connect(f); n = f; }
    const g = ac.createGain(), pk = Math.max(.0002, (o.g ?? .3) * (o.v ?? 1)), a = o.a ?? .004;
    g.gain.setValueAtTime(.0001, t); g.gain.exponentialRampToValueAtTime(pk, t + a);
    if (o.hold) g.gain.setValueAtTime(pk, t + a + o.hold);
    g.gain.exponentialRampToValueAtTime(.0001, t + d);
    n.connect(g); let tail = g;
    if (o.pan) { const p = ac.createStereoPanner(); p.pan.value = cl(o.pan, -1, 1); g.connect(p); tail = p; }
    tail.connect(o.bus || sfxB);
    s.start(t); s.stop(t + d + .05);
    return s;
  }
  function tone(type, f, t, d, o = {}) {
    const s = ac.createOscillator(); s.type = type; s.frequency.setValueAtTime(f, t);
    if (o.f2) s.frequency.exponentialRampToValueAtTime(Math.max(1, o.f2), t + (o.glide || d));
    if (o.det) s.detune.value = o.det;
    if (o.vib) { const l = ac.createOscillator(), lg = ac.createGain(); l.frequency.value = o.vib[0]; lg.gain.value = f * o.vib[1]; l.connect(lg); lg.connect(s.frequency); l.start(t); l.stop(t + d + .05); }
    return voice(s, t, d, o);
  }
  function noise(t, d, o = {}) {
    const s = ac.createBufferSource(); s.buffer = noiseBuf; s.loop = true; s.playbackRate.value = o.rate || 1;
    const off = Math.random() * 2.5; s.start = ((st0) => (tt) => st0.call(s, tt, off))(s.start);
    return voice(s, t, d, o);
  }
  // inharmonic partials: bells, blades, chains, anvils
  const BELL = [[.5, 1, 1], [1, .7, .8], [1.19, .45, .6], [1.56, .35, .5], [2, .4, .45], [2.51, .2, .35], [2.66, .15, .3], [3.01, .12, .25], [4.1, .08, .2]];
  function bell(f, t, d, g, o = {}) { for (const [r, a, dd] of BELL) tone('sine', f * r, t, d * dd + .05, { g: g * a, a: .003, pan: o.pan, bus: o.bus, det: R(-4, 4) }); }
  function metal(f, t, d, g, o = {}) {
    for (const [r, a] of [[1, 1], [2.76, .6], [5.4, .4], [8.93, .25]]) tone('sine', f * r * R(.99, 1.01), t, d * (1.1 - r / 12), { g: g * a, a: .001, pan: o.pan, bus: o.bus });
    noise(t, .03, { ft: 'highpass', ff: 3000, g: g * .8, pan: o.pan, bus: o.bus });
  }
  function choir(notes, t, d, g, o = {}) {
    // "ah" formants on detuned saws: a distant choir
    const sum = ac.createGain(), f1 = ac.createBiquadFilter(), f2 = ac.createBiquadFilter(), lp = ac.createBiquadFilter(), env = ac.createGain();
    f1.type = f2.type = 'bandpass'; f1.frequency.value = o.vow === 'o' ? 520 : 760; f2.frequency.value = o.vow === 'o' ? 900 : 1180; f1.Q.value = 5; f2.Q.value = 7;
    lp.type = 'lowpass'; lp.frequency.value = 2600; sum.connect(f1); sum.connect(f2); f1.connect(lp); f2.connect(lp); lp.connect(env); env.connect(o.bus || sfxB);
    env.gain.setValueAtTime(.0001, t); env.gain.exponentialRampToValueAtTime(g, t + (o.a ?? .8)); env.gain.setValueAtTime(g, t + Math.max(o.a ?? .8, d - (o.r ?? 1.5))); env.gain.exponentialRampToValueAtTime(.0001, t + d);
    for (const m of notes) for (const dt of [-9, 0, 8]) { const s = ac.createOscillator(); s.type = 'sawtooth'; s.frequency.value = mf(m); s.detune.value = dt + R(-3, 3);
      const l = ac.createOscillator(), lg = ac.createGain(); l.frequency.value = R(4.5, 5.6); lg.gain.value = mf(m) * .006; l.connect(lg); lg.connect(s.frequency);
      s.connect(sum); s.start(t); l.start(t); s.stop(t + d + .1); l.stop(t + d + .1); }
  }
  let camX = 0, camY = 0;
  const at = (x, y, g = 1) => { const dx = (x ?? camX) - camX, dy = (y ?? camY) - camY, d = Math.hypot(dx, dy); return { pan: cl(dx / 520, -.85, .85), v: g * cl(1.15 - d / 900, .3, 1) }; };

  /* ---------- the sound effects ---------- */
  // a kick: the pitch falls from 4x to f0 in a few ms, then a body decay; drive saturates it for weight
  function punch(t, f0, d, g, o = {}) {
    const s = ac.createOscillator(); s.type = 'sine'; s.frequency.setValueAtTime(f0 * (o.k ?? 4), t); s.frequency.exponentialRampToValueAtTime(f0, t + (o.drop ?? .04));
    voice(s, t, d, { g, a: .002, pan: o.pan, bus: o.drive ? driveB : o.bus });
    noise(t, .012, { ft: 'highpass', ff: o.click ?? 2500, g: g * .5, a: .001, pan: o.pan });
  }
  function crunch(t, d, g, o = {}) { noise(t, d, { ft: 'bandpass', ff: o.ff ?? 1200, ff2: o.ff2 ?? 300, q: .8, g, a: .002, pan: o.pan, bus: driveB }); }
  function duck(depth, rel) { if (!duckG) return; const t = now(); duckG.gain.cancelScheduledValues(t); duckG.gain.setTargetAtTime(depth, t, .01); duckG.gain.setTargetAtTime(1, t + .08, rel); }
  const SWING = { katana: [3200, 900, .16, .22], spear: [2600, 1500, .12, .2], greatsword: [1500, 280, .3, .32], daggers: [4400, 1900, .09, .16], sickle: [2700, 700, .18, .22] };
  const S = {
    swing(w, step) { const [a, b, d, g] = SWING[w] || SWING.katana, t = now(), big = step === 2;
      noise(t, d * (big ? 1.5 : 1), { ft: 'bandpass', ff: a * (big ? .8 : 1), ff2: b, q: 1.4, g: g * (big ? 2.2 : 1.7), a: .015 });
      noise(t, d * .7, { ft: 'highpass', ff: 5000, g: g * .4, a: .01 });
      tone('sine', big ? 220 : 300, t, d, { f2: 90, g: big ? .16 : .08 });
      if (w === 'greatsword') tone('sine', 120, t, .3, { f2: 55, g: .12 });
      if (w === 'sickle') for (let i = 0; i < 4; i++) metal(R(1800, 2600), t + i * .035, .08, .02);
      if (big && (w === 'katana' || w === 'spear')) metal(R(1150, 1300), t + .03, .5, .025); },
    hit(crit, x, y, big) { const t = now(), p = at(x, y), k = big ? .6 : 1;
      punch(t, crit ? 55 : 70, crit ? .32 : .22, (crit ? .9 : .65) * k * p.v, { pan: p.pan, drive: 1 });
      crunch(t, crit ? .16 : .1, (crit ? .5 : .35) * k * p.v, { ff: R(1600, 2400), ff2: 500, pan: p.pan });
      noise(t, .05, { ft: 'bandpass', ff: R(2400, 3600), q: 1.2, g: .3 * k, ...p });
      noise(t, .14, { ft: 'lowpass', ff: 700, g: .3 * k, ...p });
      if (crit) { metal(R(900, 1200), t, .5, .09, p); noise(t, .07, { ft: 'highpass', ff: 3500, g: .3, ...p }); punch(t + .02, 38, .45, .5, { k: 2, drive: 1 }); duck(.55, .15); } },
    kill(type, x, y, elite) { const t = now(), p = at(x, y);
      punch(t, 48, .45, .85 * p.v, { pan: p.pan, drive: 1, k: 5 }); crunch(t, .3, .55 * p.v, { ff: 2200, ff2: 250, pan: p.pan });
      for (let i = 0; i < 5; i++) noise(t + .03 + i * R(.02, .04), .03, { ft: 'bandpass', ff: R(700, 1600), q: 2, g: .2, ...p }); // the body breaking up
      duck(.6, .2);
      noise(t, .28, { ft: 'bandpass', ff: 900, ff2: 260, q: 1.2, g: .3, ...p });
      noise(t + .05, .8, { ft: 'bandpass', ff: 700, ff2: 180, q: 7, g: .09, a: .08, ...p }); // the shade leaving the body
      tone('sine', 95, t, .25, { f2: 40, g: .22, ...p });
      if (type === 'bat') tone('square', 2300, t, .14, { f2: 1100, g: .025, ft: 'lowpass', ff: 3000, ...p });
      if (type === 'br') { tone('sawtooth', 70, t, .7, { f2: 40, g: .09, ft: 'lowpass', ff: 300, ...p }); noise(t + .1, .3, { ft: 'lowpass', ff: 300, g: .25, ...p }); }
      if (type === 'sp') tone('triangle', 700, t, .6, { f2: 180, g: .04, ...p });
      if (type === 'dr') noise(t, .5, { ft: 'lowpass', ff: 1400, ff2: 300, g: .18, ...p });
      if (type === 'fg') for (let i = 0; i < 4; i++) metal(R(500, 1400), t + i * .06, .25, .03, p);
      if (type === 'sn') { noise(t, .9, { ft: 'highpass', ff: 3500, g: .03, a: .05, ...p }); tone('sine', 900, t, .5, { f2: 300, g: .03, ...p }); }
      if (elite) bell(mf(74), t + .05, 1.4, .05, p); },
    hurt() { const t = now(); duck(.3, .35);
      punch(t, 45, .5, 1, { drive: 1, k: 6, drop: .06 }); crunch(t, .25, .6, { ff: 900, ff2: 150 }); noise(t, .3, { ft: 'highpass', ff: 3000, ff2: 8000, g: .12 });
      tone('sine', 220, t, .25, { f2: 55, g: .5 }); noise(t, .14, { ft: 'lowpass', ff: 1600, g: .35 });
      tone('square', 98, t, .45, { g: .07, ft: 'lowpass', ff: 900 }); tone('square', 104, t, .45, { g: .07, ft: 'lowpass', ff: 900 });
      tone('sine', 52, t + .22, .16, { g: .3 }); tone('sine', 52, t + .42, .16, { g: .22 }); },
    heal() { const t = now(); bell(mf(81), t, 1, .04); bell(mf(86), t + .09, 1.1, .035); },
    jump() { const t = now(); noise(t, .13, { ft: 'bandpass', ff: 800, ff2: 1900, q: 1.2, g: .07, a: .02 }); tone('sine', 260, t, .07, { f2: 420, g: .025 }); },
    djump() { const t = now();
      for (const o of [0, .075]) noise(t + o, .12, { ft: 'lowpass', ff: 900, ff2: 260, g: .16, a: .01 });
      tone('triangle', 880, t, .35, { f2: 1320, g: .025 }); tone('sine', 1760, t + .03, .3, { g: .012 }); },
    wall() { const t = now(); noise(t, .05, { ft: 'highpass', ff: 2600, g: .1 }); tone('sine', 140, t, .06, { g: .1 }); S.jump(); },
    drop() { const t = now(); noise(t, .1, { ft: 'bandpass', ff: 500, q: 2, g: .06 }); },
    land(v) { const t = now(); noise(t, .13, { ft: 'lowpass', ff: 420, g: .1 + .3 * v }); punch(t, 55, .18, .35 * v, { k: 2.5 }); },
    step() { const t = now(); noise(t, .03, { ft: 'bandpass', ff: R(1200, 2000), q: 2, g: .028 }); tone('sine', R(110, 135), t, .04, { g: .03 }); },
    dash() { const t = now(); noise(t, .22, { ft: 'bandpass', ff: 500, ff2: 4200, q: 1.3, g: .35, a: .008 }); punch(t, 80, .15, .3, { k: 2 }); noise(t + .08, .25, { ft: 'highpass', ff: 3000, g: .03 }); tone('sine', 150, t, .12, { f2: 70, g: .1 }); },
    slamStart() { const t = now(); tone('sine', 900, t, .22, { f2: 220, g: .05 }); noise(t, .22, { ft: 'bandpass', ff: 2200, ff2: 700, q: 2, g: .07 }); },
    slam(heavy) { const t = now(); duck(.25, .5);
      punch(t, heavy ? 34 : 42, heavy ? 1 : .7, 1.1, { drive: 1, k: 6, drop: .07 }); crunch(t, .4, .8, { ff: 1800, ff2: 120 });
      tone('sine', 115, t, .55, { f2: 32, g: .6 }); noise(t, .5, { ft: 'lowpass', ff: 1300, ff2: 180, g: .4 }); noise(t, .08, { ft: 'highpass', ff: 2200, g: .2 });
      for (let i = 0; i < 9; i++) noise(t + R(.05, .45), .025, { ft: 'bandpass', ff: R(1500, 4000), q: 3, g: .05, pan: R(-.6, .6) });
      if (heavy) tone('square', 55, t, .9, { g: .1, ft: 'lowpass', ff: 220 }); },
    wax(c) { const t = now(), f = mf(84 + [0, 3, 5, 7, 10, 12, 15, 17][Math.min(7, c)]); tone('sine', f, t, .14, { g: .045 }); tone('triangle', f * 2, t, .08, { g: .015 }); },
    level() { const t = now(); [0, 3, 7, 12, 15].forEach((s, i) => bell(mf(74 + s), t + i * .08, 1.6, .05)); noise(t, .9, { ft: 'highpass', ff: 5000, g: .025, a: .3 }); },
    hexCast(x, y) { const t = now(), p = at(x, y, .8);
      tone('triangle', 520, t, .45, { f2: 1150, g: .05, vib: [9, .03], ...p }); tone('triangle', 533, t, .45, { f2: 1180, g: .04, ...p });
      noise(t, .4, { ft: 'bandpass', ff: 2600, q: 9, g: .06, a: .1, ...p }); },
    hexBurst(x, y) { const t = now(), p = at(x, y, .8);
      noise(t, .3, { ft: 'bandpass', ff: 1500, ff2: 400, q: 1.5, g: .15, ...p }); tone('sine', 320, t, .2, { f2: 80, g: .14, ...p });
      for (const f of [1900, 2600, 3300]) tone('sine', f * R(.97, 1.03), t, .25, { g: .015, ...p }); },
    spawn(type, x, y, elite) { const t = now(), p = at(x, y, .7);
      tone('sine', 230, t, .3, { f2: 110, g: .025, ...p });
      if (type === 'bat') { tone('square', 1900, t + .05, .13, { f2: 2700, g: .02, ft: 'lowpass', ff: 4000, ...p }); for (let i = 0; i < 3; i++) noise(t + i * .06, .05, { ft: 'lowpass', ff: 700, g: .06, ...p }); }
      else if (type === 'sp') noise(t, .7, { ft: 'bandpass', ff: 3100, q: 11, g: .06, a: .18, ...p });
      else if (type === 'br') tone('sawtooth', 58, t, .85, { f2: 46, g: .07, a: .12, ft: 'lowpass', ff: 320, ...p });
      else tone('sawtooth', 95, t, .65, { f2: 72, g: .04, a: .12, ft: 'bandpass', ff: 520, q: 4, ...p });
      if (elite) bell(mf(62), t, 1.5, .04, p); },
    roar(x, y) { const t = now(), p = at(x, y); duck(.3, 1.2);
      for (const f of [55, 82]) tone('sawtooth', f, t, 2, { f2: f * .75, g: .14, a: .2, bus: driveB, ft: 'lowpass', ff: 700 });
      for (const f of [62, 66, 93]) tone('sawtooth', f, t, 1.9, { f2: f * .8, g: .1, a: .25, ft: 'lowpass', ff: 300, ff2: 900, fg: .7, ...p });
      noise(t, 1.7, { ft: 'bandpass', ff: 480, ff2: 260, q: 2, g: .12, a: .25, ...p }); tone('sine', 40, t, 2.2, { g: .3, a: .3 }); },
    big(x, y) { const t = now(), p = at(x, y); duck(.2, .7);
      punch(t, 30, 1.3, 1.2, { drive: 1, k: 7, drop: .08 }); crunch(t, .6, .9, { ff: 2400, ff2: 90 });
      tone('sine', 90, t, 1.1, { f2: 28, g: .7 }); noise(t, .9, { ft: 'lowpass', ff: 1600, ff2: 120, g: .45, ...p }); noise(t, .1, { ft: 'highpass', ff: 1800, g: .22, ...p });
      for (let i = 0; i < 12; i++) noise(t + R(.08, .7), .03, { ft: 'bandpass', ff: R(900, 3500), q: 3, g: .05, pan: R(-.8, .8) }); },
    wind(x, y) { const t = now(), p = at(x, y);
      for (let i = 0; i < 11; i++) metal(R(1700, 3200), t + R(0, .6), .1, .025, p);
      tone('sawtooth', 52, t, .8, { f2: 64, g: .09, a: .55, ft: 'lowpass', ff: 260, ...p }); },
    quake() { const t = now(); noise(t, 1.1, { ft: 'lowpass', ff: 140, g: .7, a: .05 }); noise(t, .9, { ft: 'lowpass', ff: 400, g: .25, bus: driveB }); tone('sine', 36, t, 1, { g: .25 }); },
    bossDeath(x, y) { const t = now(), p = at(x, y); duck(.1, 2.5);
      punch(t, 26, 3, 1.3, { drive: 1, k: 8, drop: .12 }); crunch(t, 1.4, 1, { ff: 3000, ff2: 60 });
      tone('sine', 62, t, 2.8, { f2: 24, g: .75 }); noise(t, 2.6, { ft: 'lowpass', ff: 2200, ff2: 90, g: .5, ...p });
      for (let i = 0; i < 18; i++) tone('sine', R(1800, 5200), t + .1 + R(0, .5), R(.2, .6), { g: .012, pan: R(-.9, .9) });
      bell(mf(38), t + .2, 6, .12); choir([50, 57, 62, 66], t + .7, 4.5, .045, { a: 1.2 }); },
    strepitus() { const t = now(); // the old office's noise: books and pews struck in the dark
      for (let i = 0, tt = 0; i < 30; i++) { tt += .13 * Math.pow(.955, i) + R(0, .04); const g = .07 + i / 30 * .22, pan = R(-.9, .9);
        noise(t + tt, .08, { ft: 'bandpass', ff: R(280, 900), q: 3, g, pan }); tone('sine', R(150, 260), t + tt, .06, { f2: 90, g: g * .7, pan }); }
      noise(t, 2.4, { ft: 'lowpass', ff: 90, ff2: 260, g: .35, a: 1.8 }); tone('sine', 34, t, 2.6, { g: .35, a: 1.6 });
      S.big(); tOff += 2.15; S.big(); tOff -= 2.15; },
    candle(left) { const t = now();
      noise(t, .28, { ft: 'bandpass', ff: 1300, ff2: 380, q: 1.2, g: .07, a: .02 }); noise(t + .1, .7, { ft: 'highpass', ff: 4200, g: .012, a: .2 });
      bell(mf(50 - Math.round((15 - left) / 3)), t + .35, 5, .14); },
    brazier(x, y) { const t = now(), p = at(x, y);
      noise(t, .7, { ft: 'lowpass', ff: 200, ff2: 2600, fg: .2, g: .32, a: .07, ...p }); tone('sine', 80, t, .45, { g: .12, ...p });
      for (let i = 0; i < 14; i++) noise(t + R(.05, .9), .015, { ft: 'highpass', ff: 3000, g: .05, ...p });
      bell(mf(79), t + .15, 1.4, .03, p); },
    ember(x, y) { const t = now(), p = at(x, y, .7); noise(t, .45, { ft: 'lowpass', ff: 260, ff2: 1800, fg: .15, g: .18, a: .04, ...p }); },
    gale(x, y) { const t = now(), p = at(x, y); noise(t, .55, { ft: 'bandpass', ff: 400, ff2: 1700, q: 1, g: .16, a: .1, ...p }); },
    veil() { const t = now(); for (const f of [1568, 2093, 2637]) tone('sine', f * R(.995, 1.005), t, .55, { g: .028 }); },
    revive() { const t = now();
      noise(t, .55, { ft: 'highpass', ff: 1200, g: .1, a: .5 }); tone('sine', 50, t + .5, 1.6, { f2: 30, g: .55 }); noise(t + .5, .1, { ft: 'highpass', ff: 2500, g: .3 });
      choir([62, 66, 69, 74], t + .45, 3, .06, { a: .08 }); bell(mf(86), t + .5, 2, .07); },
    banner() { const t = now(); bell(mf(69), t, 1.6, .035); },
    slain() { const t = now(); for (const m of [38, 45, 50, 54]) tone('sawtooth', mf(m), t, 2.8, { g: .045, a: .25, ft: 'lowpass', ff: 900 }); tone('sine', 70, t, .6, { f2: 50, g: .3 }); },
    uiOpen() { const t = now(); noise(t, .16, { ft: 'bandpass', ff: 2400, q: .7, g: .06, a: .03 }); bell(mf(74), t + .04, 1, .03); },
    uiMove() { const t = now(); tone('sine', 1500, t, .04, { g: .045 }); noise(t, .015, { ft: 'highpass', ff: 4000, g: .03 }); },
    uiOk() { const t = now(); bell(mf(76), t, 1.4, .06); tone('sine', 110, t, .12, { f2: 60, g: .2 }); },
    uiLeave() { const t = now(); tone('sine', 900, t, .06, { g: .04 }); tone('sine', 640, t + .07, .08, { g: .04 }); },
    over(victory) { const t = now(); if (victory) { choir([62, 66, 69, 74, 78], t, 6, .07, { a: 1.5 }); [74, 78, 81, 86].forEach((m, i) => bell(mf(m), t + .4 + i * .3, 3, .05)); }
      else bell(mf(38), t, 6, .16); },
    // death: the stagger, the blade biting stone as the Wick kneels, the crumble to ash, EXTINGUISHED
    die0() { const t = now(); S.hurt(); punch(t, 28, 1.6, 1.1, { drive: 1, k: 8, drop: .1 }); noise(t, 1.3, { ft: 'lowpass', ff: 3200, ff2: 160, g: .2, a: .02 }); tone('sine', 55, t + .5, .2, { g: .35 }); tone('sine', 55, t + .75, .2, { g: .25 }); },
    die1() { const t = now(); metal(R(620, 700), t, .9, .05); noise(t, .15, { ft: 'lowpass', ff: 500, g: .25 }); tone('sine', 80, t, .2, { f2: 45, g: .25 }); },
    die2() { const t = now(); for (let i = 0; i < 40; i++) noise(t + R(0, 1.3), .02, { ft: 'bandpass', ff: R(2000, 6000), q: 4, g: .03, pan: R(-.4, .4) }); noise(t, 1.8, { ft: 'bandpass', ff: 800, q: 1.2, g: .05, a: .6 }); },
    die3() { const t = now(); punch(t, 30, 3, 1, { drive: 1, k: 3, drop: .3 }); tone('sine', 41, t, 3, { g: .5 }); bell(mf(26), t, 9, .22); choir([38, 45, 50, 53], t + .2, 5.5, .05, { a: 1.2, vow: 'o' }); },
    // cutscenes
    shot() { const t = now(); noise(t, .25, { ft: 'bandpass', ff: 500, ff2: 1500, q: .8, g: .03, a: .08 }); },
    flash(red) { const t = now(); duck(.3, .6); punch(t, red ? 30 : 40, 1.1, 1, { drive: 1, k: 6 });
      if (red) { tone('sine', 70, t, 1.2, { f2: 26, g: .6 }); noise(t, .7, { ft: 'lowpass', ff: 900, ff2: 120, g: .4 }); tone('sawtooth', 48, t, .9, { g: .08, ft: 'lowpass', ff: 300 }); }
      else { noise(t, .12, { ft: 'highpass', ff: 2600, g: .32 }); tone('sine', 1200, t, .9, { f2: 600, g: .03 }); tone('sine', 60, t, .8, { f2: 30, g: .45 }); }
      noise(t, .6, { ft: 'highpass', ff: 6000, g: .02, a: .02 }); },
    rumble(amt) { const t = now(); noise(t, .9, { ft: 'lowpass', ff: 160, g: .2 + amt * .3 }); tone('sine', 38, t, .8, { g: .15 + amt * .25 }); },
    card(col) { const t = now(); tone('sine', 46, t, 2.4, { f2: 34, g: .4 }); bell(mf(col === 'gold' ? 50 : 43), t + .1, 6, .13); noise(t, 1.2, { ft: 'bandpass', ff: 300, q: .7, g: .05, a: .4 }); },
    eyes() { const t = now(); tone('sine', 2400, t, 1.2, { f2: 3200, g: .015, a: .4 }); noise(t, 1, { ft: 'bandpass', ff: 5000, q: 6, g: .03, a: .6 }); },
    focus() { const t = now(); noise(t, .6, { ft: 'bandpass', ff: 300, ff2: 4500, q: 2, g: .07, a: .45 }); },
    streak() { const t = now(); noise(t, .5, { ft: 'bandpass', ff: 1800, ff2: 700, q: 1, g: .06, a: .06 }); },
    // the dungeon enemies: the Drowned crouch and pounce, the Forged throw blades, the Snuffers blink and slash
    tele(type, x, y) { const t = now(), p = at(x, y, .8);
      if (type === 'dr') { for (let i = 0; i < 6; i++) { const f = R(180, 420); tone('sine', f, t + i * .055, .07, { f2: f * 1.8, g: .05, ...p }); } noise(t, .4, { ft: 'lowpass', ff: 500, g: .06, a: .1, ...p }); }
      else if (type === 'fg') { noise(t, .42, { ft: 'bandpass', ff: 1800, ff2: 4200, q: 8, g: .08, a: .3, ...p }); metal(R(900, 1100), t + .38, .3, .03, p); }
      else if (type === 'sn') { noise(t, .3, { ft: 'highpass', ff: 1500, g: .09, a: .25, ...p }); tone('sine', 1900, t, .4, { f2: 600, g: .03, ...p }); noise(t + .28, .2, { ft: 'bandpass', ff: 2600, ff2: 900, q: 1.3, g: .2, ...p }); } },
    pounce(x, y) { const t = now(), p = at(x, y); noise(t, .3, { ft: 'bandpass', ff: 700, ff2: 2200, q: 1, g: .14, ...p }); tone('sawtooth', 120, t, .3, { f2: 70, g: .05, ft: 'lowpass', ff: 600, ...p }); },
    blade(x, y) { const t = now(), p = at(x, y); for (let i = 0; i < 6; i++) noise(t + i * .07, .06, { ft: 'bandpass', ff: 2400, q: 3, g: .07 * (1 - i / 7), ...p }); metal(R(1400, 1600), t, .5, .025, p); },
    bladeEnd(x, y) { const t = now(), p = at(x, y); metal(R(700, 900), t, .6, .05, p); noise(t, .06, { ft: 'highpass', ff: 2500, g: .12, ...p }); },
    anvil() { const t = now(); metal(R(480, 560), t + .3, 1.4, .05); metal(R(480, 560), t + 1.4, 1.4, .04); }
  };
  let lastPlay = {};
  const play = (n, ...a) => { if (!ac || muted) return; const t = performance.now(); if (lastPlay[n] && t - lastPlay[n] < (GAP[n] ?? 20)) return; lastPlay[n] = t; logE(n); try { S[n](...a); } catch (e) {} };
  const GAP = { tele: 60, blade: 100, bladeEnd: 80, hit: 28, step: 90, wax: 32, spawn: 220, ember: 120, hexCast: 120, hexBurst: 80, veil: 300, kill: 40, uiMove: 40, banner: 400 };

  /* ---------- gibberish voices: formant-synthesized speech that follows the letters of each line ---------- */
  const VOW = { a: [730, 1090, 2440], e: [530, 1840, 2480], i: [300, 2200, 3000], o: [570, 840, 2410], u: [320, 870, 2240], y: [380, 1900, 2600], '@': [500, 1400, 2400] };
  const CAST = {
    narrator: { f0: 104, fm: 1, br: .32, rate: 1, g: .55, vib: .01 },
    'ABBESS HILD': { f0: 196, fm: 1.16, br: .26, rate: .94, g: .6, vib: .02 },
    'SAINT UMBER': { f0: 80, fm: .9, br: .4, rate: .84, g: .7, vib: .008, sub: 1, whisper: 1 },
    '???': { f0: 80, fm: .9, br: .5, rate: .8, g: .6, vib: .008, sub: 1, whisper: 1 },
    'THE CHAIN WARDEN': { f0: 66, fm: .84, br: .2, rate: .9, g: .75, vib: .01, growl: 31 },
    'THE HOLLOW KING': { f0: 94, fm: .92, br: .3, rate: .92, g: .7, vib: .045, water: 1 },
    'THE ASHEN JARL': { f0: 88, fm: .96, br: .18, rate: 1.1, g: .85, vib: .015, growl: 22 }
  };
  let line = null;
  function stopLine(t) { if (!line) return; const L = line; line = null; L.g.gain.cancelScheduledValues(t); L.g.gain.setTargetAtTime(0, t, .03); setTimeout(() => L.nodes.forEach(n => { try { n.stop(); } catch (e) {} }), 300); }
  function speak(who, text, maxDur) {
    if (!ac || muted) return; const t0 = now() + .2; stopLine(now());
    const c = CAST[who] || CAST.narrator; logE('voice:' + (who || 'narrator'));
    // plan: syllables from the letters (vowel nucleus, consonant onset), pauses at punctuation
    const plan = []; const words = text.split(/\s+/).filter(Boolean);
    for (const w of words) {
      const lw = w.toLowerCase(), groups = lw.match(/[^aeiouy]*[aeiouy]+/g) || [lw]; const n = Math.min(4, groups.length);
      for (let i = 0; i < n; i++) { const gs = groups[i], v = gs.match(/[aeiouy]/) ? gs.match(/[aeiouy]/)[0] : '@', on = (gs.match(/[a-z]/) || ['h'])[0];
        plan.push({ v, on: 'aeiouy'.includes(on) ? '' : on, last: i === n - 1, stress: i === 0 && w.length > 3, up: /!/.test(w), ask: /\?/.test(w) }); }
      const tail = w.match(/[.,!?;:…-]+$/); plan[plan.length - 1].pause = !tail ? .045 : /\.\.\.|…/.test(tail[0]) ? .5 : /[.!?]/.test(tail[0]) ? .34 : .18;
    }
    let dur = plan.reduce((s, p) => s + .135 / c.rate + (p.last ? p.pause : 0), 0), k = 1;
    if (dur > maxDur - .3) k = Math.max(.62, (maxDur - .3) / dur);
    // a source (buzz + breath) through three formant filters, all automated ahead of time
    const g = ac.createGain(); g.gain.value = c.g; const lp = ac.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = c.water ? 1900 : 3400; g.connect(lp); lp.connect(voxB);
    const src = ac.createOscillator(); src.type = 'sawtooth'; src.frequency.value = c.f0; const amp = ac.createGain(); amp.gain.value = 0; src.connect(amp);
    const ao = ac.createGain(); ao.gain.value = c.growl ? .75 : 1; amp.connect(ao);
    const nodes = [src]; let sub = null;
    if (c.sub) { sub = ac.createOscillator(); sub.type = 'sawtooth'; sub.frequency.value = c.f0 / 2; const sg = ac.createGain(); sg.gain.value = .55; sub.connect(sg); sg.connect(amp); nodes.push(sub); }
    const br = ac.createBufferSource(); br.buffer = noiseBuf; br.loop = true; const brG = ac.createGain(); brG.gain.value = 0; br.connect(brG); nodes.push(br);
    const F = [0, 1, 2].map(i => { const f = ac.createBiquadFilter(); f.type = 'bandpass'; f.Q.value = [7, 11, 13][i]; f.frequency.value = VOW['@'][i] * c.fm; const fg = ac.createGain(); fg.gain.value = [1, .55, .28][i] * (i ? 1.6 : 1); ao.connect(f); brG.connect(f); f.connect(fg); fg.connect(g); return f; });
    const cons = ac.createBufferSource(); cons.buffer = noiseBuf; cons.loop = true; const cf = ac.createBiquadFilter(); cf.type = 'bandpass'; const cg = ac.createGain(); cg.gain.value = 0; cons.connect(cf); cf.connect(cg); cg.connect(g); nodes.push(cons);
    if (c.vib) { const l = ac.createOscillator(), lg = ac.createGain(); l.frequency.value = c.water ? 6.5 : 5.2; lg.gain.value = c.f0 * c.vib; l.connect(lg); lg.connect(src.frequency); if (sub) { const l2 = ac.createGain(); l2.gain.value = c.f0 * c.vib * .5; l.connect(l2); l2.connect(sub.frequency); } nodes.push(l); }
    if (c.growl) { const l = ac.createOscillator(), lg = ac.createGain(); l.frequency.value = c.growl; lg.gain.value = .3; l.connect(lg); lg.connect(ao.gain); nodes.push(l); }
    if (c.whisper) { const wg = ac.createGain(); wg.gain.value = .6; brG.connect(wg); wg.connect(g); }
    let t = t0, i = 0; const N = plan.length;
    for (const p of plan) {
      const sd = .135 / c.rate * k * (p.stress ? 1.15 : 1) * R(.88, 1.12), decl = 1 - .16 * (i / Math.max(1, N - 1));
      let f0 = c.f0 * decl * (p.stress ? 1.09 : 1) * (p.up ? 1.18 : 1) * R(.96, 1.04); if (p.ask && p.last) f0 *= 1.25;
      const vf = VOW[p.v] || VOW['@'], on = p.on, cd = !on ? 0 : 'szcfhxjv'.includes(on) ? .055 : 'ptkbdgq'.includes(on) ? .022 : .035;
      if (cd) { const fric = 'szcxj'.includes(on), soft = 'fhv'.includes(on), nasal = 'mnlrw'.includes(on);
        if (!nasal) { cf.frequency.setValueAtTime(fric ? 5200 : soft ? 2200 : 1600, t); cf.Q.value = fric ? 2 : 1; cg.gain.setValueAtTime(0, t); cg.gain.linearRampToValueAtTime((fric ? .32 : soft ? .14 : .4) * (c.whisper ? 1.2 : 1), t + .006); cg.gain.linearRampToValueAtTime(0, t + cd); }
        amp.gain.setTargetAtTime(nasal ? .25 : 0, t, .01); if (nasal) F[0].frequency.setTargetAtTime(260 * c.fm, t, .01); }
      const tv = t + cd;
      src.frequency.setTargetAtTime(f0, tv, .025); if (sub) sub.frequency.setTargetAtTime(f0 / 2 * 1.004, tv, .025);
      F.forEach((f, j) => f.frequency.setTargetAtTime(vf[j] * c.fm * R(.97, 1.03), tv, .022));
      const a = (p.stress ? 1 : .8) * (p.up ? 1.25 : 1);
      amp.gain.setTargetAtTime(a * .5, tv, .015); brG.gain.setTargetAtTime(c.br * a * .35, tv, .02);
      const te = tv + Math.max(.05, sd - cd);
      if (p.last) { amp.gain.setTargetAtTime(0, te - .02, .02); brG.gain.setTargetAtTime(0, te - .02, .03); src.frequency.setTargetAtTime(f0 * .9, te - .04, .05); }
      else amp.gain.setTargetAtTime(a * .32, te - .015, .012);
      t = te + (p.last ? p.pause * k : 0); i++;
    }
    const end = t + .3; for (const n of nodes) { n.start(t0); n.stop(end); }
    line = { g, nodes, end };
  }

  /* ---------- the score: drone, choir, bells and drums that follow the chapter, the candles and the fight ---------- */
  const CHM = [
    { root: 38, sc: [0, 1, 3, 5, 7, 8, 10], bpm: 62, prog: [[0, 2, 4], [5, 0, 2], [3, 5, 0], [1, 3, 5]], amb: 'chains' },  // the Pit: D phrygian
    { root: 35, sc: [0, 2, 3, 5, 7, 8, 10], bpm: 58, prog: [[0, 2, 4], [5, 0, 2], [6, 1, 3], [4, 6, 1]], amb: 'drips' },   // the Well: B aeolian
    { root: 40, sc: [0, 1, 3, 5, 6, 8, 10], bpm: 70, prog: [[0, 2, 4], [1, 3, 5], [4, 6, 1], [0, 2, 5]], amb: 'forge' },   // the Bladeworks: E locrian
    { root: 36, sc: [0, 1, 4, 5, 7, 8, 11], bpm: 54, prog: [[0, 2, 4], [1, 3, 5], [5, 0, 2], [4, 6, 1]], amb: 'whispers' } // the Throne: C phrygian dominant
  ];
  const deg = (ch, d, oct = 0) => { const n = ch.sc.length, o = Math.floor(d / n); return ch.root + ch.sc[((d % n) + n) % n] + 12 * (o + oct); };
  const M = { ch: 0, k: 0, inten: 0, boss: 0, mode: 'game', beat: 0, next: 0, bar: 0, hp: 9, dark: 0 };
  let drone, pad, amb, sched = null;
  function startMusic(offline) {
    const t = now();
    // drone: detuned saws and a sub, under a slowly breathing low-pass
    const dg = ac.createGain(); dg.gain.value = .0001; const df = ac.createBiquadFilter(); df.type = 'lowpass'; df.frequency.value = 220; df.Q.value = 2; df.connect(dg); dg.connect(musB);
    const dl = ac.createOscillator(), dlg = ac.createGain(); dl.frequency.value = .06; dlg.gain.value = 90; dl.connect(dlg); dlg.connect(df.frequency); dl.start();
    const dos = [[-12, 'sawtooth', .5, -7], [-12, 'sawtooth', .5, 7], [-12, 'sine', .9, 0], [-5, 'sawtooth', .22, 3], [0, 'triangle', .12, 0]].map(([o, ty, gg, det]) => {
      const s = ac.createOscillator(); s.type = ty; s.detune.value = det; s.frequency.value = mf(CHM[0].root + o); const g = ac.createGain(); g.gain.value = gg; s.connect(g); g.connect(df); s.start(); return { s, o }; });
    dg.gain.setTargetAtTime(.3, t, 2);
    drone = { g: dg, f: df, os: dos };
    // choir pad: four voices that glide between chords
    const pg = ac.createGain(); pg.gain.value = .0001; const pf = ac.createBiquadFilter(); pf.type = 'lowpass'; pf.frequency.value = 2200; pf.connect(pg); pg.connect(musB);
    const sum = ac.createGain(); sum.gain.value = .5; const f1 = ac.createBiquadFilter(), f2 = ac.createBiquadFilter(); f1.type = f2.type = 'bandpass'; f1.frequency.value = 650; f2.frequency.value = 1080; f1.Q.value = 4; f2.Q.value = 6;
    sum.connect(f1); sum.connect(f2); f1.connect(pf); f2.connect(pf); const dry = ac.createGain(); dry.gain.value = .18; sum.connect(dry); dry.connect(pf);
    const vs = [0, 1, 2, 3].map(i => { const ss = [-8, 7].map(det => { const s = ac.createOscillator(); s.type = 'sawtooth'; s.detune.value = det; s.frequency.value = mf(50); s.connect(sum); s.start(); return s; });
      const l = ac.createOscillator(), lg = ac.createGain(); l.frequency.value = 4.6 + i * .37; lg.gain.value = 1.4; l.connect(lg); ss.forEach(s => lg.connect(s.frequency)); l.start(); return ss; });
    pad = { g: pg, f: pf, vs };
    // room tone: wind in the nave
    const an = ac.createBufferSource(); an.buffer = noiseBuf; an.loop = true; const af = ac.createBiquadFilter(); af.type = 'bandpass'; af.frequency.value = 380; af.Q.value = .8;
    const al = ac.createOscillator(), alg = ac.createGain(); al.frequency.value = .09; alg.gain.value = 180; al.connect(alg); alg.connect(af.frequency); al.start();
    const ag = ac.createGain(); ag.gain.value = .0001; an.connect(af); af.connect(ag); ag.connect(ambB); an.start(); ag.gain.setTargetAtTime(.09, t, 2);
    const sl = ac.createBufferSource(); sl.buffer = noiseBuf; sl.loop = true; const sf = ac.createBiquadFilter(); sf.type = 'bandpass'; sf.frequency.value = 3200; sf.Q.value = 1.4; const sg = ac.createGain(); sg.gain.value = 0;
    sl.connect(sf); sf.connect(sg); sg.connect(sfxB); sl.start(); // wall-slide scrape, gated by the game
    amb = { g: ag, slide: sg };
    if (!offline) { M.next = t + .3; sched = setInterval(tickMusic, 60); }
    setChord(0, t);
  }
  function setChord(ci, t) {
    const ch = CHM[M.ch], c = M.mode === 'victory' ? null : ch.prog[ci % ch.prog.length];
    const notes = c ? [deg(ch, c[0], 1), deg(ch, c[1], 1), deg(ch, c[2], 1), deg(ch, c[0], 2)] : [ch.root + 12, ch.root + 16, ch.root + 19, ch.root + 24];
    pad.vs.forEach((ss, i) => ss.forEach(s => s.frequency.setTargetAtTime(mf(notes[i]), t, .9)));
  }
  function setRoot(t) { const ch = CHM[M.ch]; drone.os.forEach(({ s, o }) => s.frequency.setTargetAtTime(mf(ch.root + o), t, 2.5)); }
  function taiko(t, g) { tone('sine', 78, t, .55, { f2: 40, g, bus: musB }); noise(t, .14, { ft: 'lowpass', ff: 320, g: g * .6, bus: musB }); }
  function frame(t, g) { tone('sine', 170, t, .18, { f2: 100, g, bus: musB }); noise(t, .08, { ft: 'bandpass', ff: 900, q: 1.5, g: g * .5, bus: musB }); }
  function pluck(m, t, g) { const p = R(-.6, .6); tone('triangle', mf(m), t, 1.8, { g, pan: p, bus: musB }); tone('sine', mf(m) * 2, t, .9, { g: g * .35, pan: p, bus: musB }); }
  function ambEvent(t) {
    const kind = CHM[M.ch].amb, p = R(-.9, .9);
    if (kind === 'chains') { for (let i = 0, n = 2 + Math.floor(R(0, 4)); i < n; i++) metal(R(1500, 2600), t + i * R(.06, .14), .12, .012, { pan: p, bus: ambB }); }
    else if (kind === 'drips') { const f = R(1100, 1900); tone('sine', f, t, .1, { f2: f * .45, glide: .05, g: .035, pan: p, bus: ambB }); }
    else if (kind === 'forge') { if (Math.random() < .5) metal(R(380, 520), t, 1.2, .016, { pan: p, bus: ambB }); else noise(t, 1.4, { ft: 'lowpass', ff: 380, g: .05, a: .6, pan: p, bus: ambB }); }
    else noise(t, 1.3, { ft: 'bandpass', ff: R(1400, 3200), q: 12, g: .03, a: .35, pan: p, bus: ambB });
  }
  let ambT = 0, hbT = 0;
  function tickMusic() {
    if (!ac) return; const t = now(); if (M.next < t - .5) M.next = t + .05;
    const ch = CHM[M.ch], bpm = ch.bpm * (M.boss ? 1.18 : 1), bt = 60 / bpm;
    while (M.next < t + .25) { beat(M.next, ch, bt, M.mode === 'game', {}); M.next += bt; M.beat++; }
    if ((ambT -= .06) <= 0) { ambT = R(2, 6); if (M.mode === 'game') ambEvent(t + .05); }
    // heartbeat at one heart
    if (M.mode === 'game' && M.hp === 1 && (hbT -= .06) <= 0) { hbT = .95; tone('sine', 54, t + .05, .16, { g: .28 }); tone('sine', 50, t + .25, .16, { g: .2 }); }
  }
  // stems (offline renders for Godot): base = drone, choir, bells, plucks; drums = the fight layer; boss = everything at boss tempo
  function beat(tt, ch, bt, fight, o) {
    {
      const b = M.beat % 4, bar = Math.floor(M.beat / 4), base = o.stem !== 'drums', drums = o.stem !== 'base';
      if (b === 0 && bar % 2 === 0 && pad) setChord(bar / 2, tt);
      if (base && b === 0 && bar % 8 === 0) bell(mf(ch.root - 12 + (M.dark ? 0 : 12)), tt, 7, .05, { bus: musB });
      if (base && M.mode !== 'death') {
        const pp = M.mode === 'cut' ? .08 : .12 + M.inten * .28 - M.k * .06;
        if (Math.random() < pp) { M.mel = cl((M.mel ?? 4) + Math.round(R(-2.4, 2.4)), 0, 9); pluck(deg(ch, M.mel, 2), tt + (Math.random() < .3 ? bt / 2 : 0), .04); }
      }
      if (drums && fight && (M.inten > .32 || M.boss)) {
        const g = M.boss ? .32 : .12 + M.inten * .18;
        if (b === 0 || b === 2) taiko(tt, g);
        if (M.boss && (b === 3)) taiko(tt + bt / 2, g * .7);
        if (M.inten > .6 || M.boss) { if (b === 1 || b === 3) frame(tt, g * .45); }
      }
      if (drums && fight && M.boss) { // ostinato under a boss
        const pat = [0, 0, 1, 0, 0, 0, 1, -2];
        for (let e = 0; e < 2; e++) { const s = pat[(b * 2 + e) % 8]; tone('sawtooth', mf(ch.root - 12 + s), tt + e * bt / 2, bt / 2 * .9, { g: .055, ft: 'lowpass', ff: 520, bus: musB }); }
      }
    }
  }
  function mixTo(t) {
    const k = M.k, mode = M.mode;
    const mg = muted ? 0 : mode === 'death' ? .05 : mode === 'cut' ? .15 : mode === 'menu' ? .14 : .19;
    musB.gain.setTargetAtTime(mg, t, mode === 'death' ? 1.2 : .6);
    musF.frequency.setTargetAtTime(mode === 'death' ? 240 : mode === 'menu' ? 1100 : 16000, t, mode === 'death' ? .9 : .25);
    drone.g.gain.setTargetAtTime(mix(.24, .38, k) * (M.boss ? 1.2 : 1), t, 1.5);
    drone.f.frequency.setTargetAtTime(M.boss ? 340 : 220, t, 1);
    pad.g.gain.setTargetAtTime((mode === 'victory' ? .5 : mix(.34, .1, k)) * (M.dark && !M.boss ? .25 : 1), t, 2);
    pad.f.frequency.setTargetAtTime(mode === 'victory' ? 3400 : mix(2300, 650, k), t, 2);
    amb.g.gain.setTargetAtTime(mode === 'cut' ? .03 : mode === 'death' ? .02 : .09 + k * .05, t, 1);
  }

  /* ---------- the watcher: compares the game state with the last frame ---------- */
  const P = { init: false };
  let stepPh = 0, waxC = 0, waxT = 0, cutKey = '', cutChars = 0, deathStage = -1, lastMix = 0, mixKey = '';
  function watch(st, rdt) {
    toast = Math.max(0, toast - (rdt || 0));
    const p = st.p; if (!p) return;
    if (st.cam) { camX = st.cam.x; camY = st.cam.y; }
    const live = st.E.filter(e => !e.dead), ov = st.ov, cut = st.cut;
    const fresh = arr => { const r = []; for (const o of arr || []) if (!o.__a) { o.__a = 1; r.push(o); } return r; };
    if (!P.init || !ac) {
      // the first frame, or no sound yet: take the state as it is, so nothing fires in a burst later
      fresh(st.N); fresh(st.rings); fresh(st.proj); fresh(st.quakes); fresh(st.E);
      Object.assign(P, { init: true, hp: st.hp, kills: st.kills, lvl: st.lvl, depth: st.depth, banner: st.banner && st.banner.text, dying: st.dying, ovk: ov && ov.kind, ovp: ov && ov.pick, ovd: ov && ov.done,
        atk: p.atk, step: p.atk && p.atk.step, dash: p.dash, dj: p.dj, ground: p.ground, slam: p.slam, kick: p.kick, dropT: p.dropT, wax: st.runWax, hidden: st.hidden, bosses: st.bosses, proj: [...(st.proj || [])], vy: p.vy, fallV: 0, ba: st.boss && st.boss.ai, victory: st.victory, run: st.run, live: st.E.slice() });
      if (!ac) return;
    }
    const mute = muted;
    // ---- cutscenes: shot cues and voices
    if (cut) {
      const shots = STORY.SC && STORY.SC[cut.id], shot = shots && shots[cut.i], key = cut.id + ':' + cut.i;
      if (shot && key !== cutKey) {
        cutKey = key; cutChars = 0; stopLine(now());
        const src = String(shot.draw);
        if (shot.flash) play('flash', shot.flash === 'red'); else play('shot');
        if (shot.shake) { const [a, b] = shot.shake; setTimeout(() => st.cut && cutKey === key && play('rumble', b), a * 1000); }
        if (/card\(/.test(src)) play('card', /C\.gold/.test(src) ? 'gold' : 'x');
        if (/eyesClose\(/.test(src)) play('eyes');
        if (/focus\(/.test(src)) play('focus');
        if (/streaks\(/.test(src)) play('streak');
        if (/forge\(/.test(src)) play('anvil');
        if (shot.say && !mute) speak(shot.say[0], shot.say[1], shot.d);
        if (cut.id === 'end3' && cut.i === shots.length - 3) { M.mode = 'victory'; }
      }
    } else if (cutKey) { cutKey = ''; stopLine(now()); if (M.mode === 'cut') M.mode = 'game'; }
    // ---- menus and the summary
    if (ov && ov.kind !== P.ovk) { if (ov.kind === 'over') play('over', !!ov.victory); else play('uiOpen'); }
    if (ov && ov.kind === P.ovk && ov.pick !== P.ovp && !ov.done) play('uiMove');
    if (ov && ov.done && !P.ovd) play(ov.pick < 0 ? 'uiLeave' : 'uiOk');
    // ---- the player
    if (!st.ov && !cut) {
      if (p.atk && (p.atk !== P.atk || p.atk.step !== P.step)) play('swing', st.weapon, p.atk.step);
      if (p.dash > 0 && !(P.dash > 0)) play('dash');
      if (p.dj && !P.dj) play('djump');
      else if (p.kick > (P.kick || 0) + .05) play('wall');
      else if (P.ground && !p.ground && p.vy < -500) play('jump');
      if (p.dropT > (P.dropT || 0) + .05) play('drop');
      if (p.slam && !P.slam) play('slamStart');
      if (!p.ground) P.fallV = Math.max(P.fallV || 0, p.vy || 0);
      if (p.ground && !P.ground && !P.slam && !st.dying) { play('land', cl((P.fallV || 0) / 1400, .15, 1)); P.fallV = 0; }
      if (p.ground && Math.abs(p.vx) > 70 && !p.dash) { const ph = Math.floor((p.ph || 0) / Math.PI); if (ph !== stepPh) { stepPh = ph; play('step'); } }
      const sl = p.slideT > 0 && !p.ground ? .12 : 0; amb.slide.gain.setTargetAtTime(mute ? 0 : sl, now(), .04);
    } else amb.slide.gain.setTargetAtTime(0, now(), .04);
    // ---- numbers: hits, hearts, level-ups
    let hits = 0;
    for (const n of fresh(st.N)) {
      if (typeof n.v === 'number') { if (hits++ < 3) play('hit', n.crit, n.x, n.y, hits > 1); }
      else if (/♥/.test(n.v) && /^\+/.test(n.v)) play('heal');
    }
    if (st.hp < P.hp && st.hp > 0) play('hurt');
    if (st.hidden === false && P.hidden === true && st.hp > 0) play('revive');
    if (st.lvl > P.lvl) play('level');
    if (st.runWax > P.wax) { const tt = performance.now(); waxC = tt - waxT < 450 ? waxC + 1 : 0; waxT = tt; play('wax', waxC); }
    // ---- kills, spawns, the boss
    for (const e of P.live || []) if (e.dead && !e.__k) { e.__k = 1; if (e.type !== 'boss') play('kill', e.type, e.x, e.y - e.h / 2, e.elite); }
    if (st.bosses > P.bosses) play('bossDeath', camX, camY);
    for (const e of fresh(st.E)) { if (e.type === 'boss') play('roar', e.x, e.y); else play('spawn', e.type, e.x, e.y, e.elite); }
    const ba = st.boss && st.boss.ai; if (ba === 'wind' && P.ba !== 'wind') play('wind', st.boss.x, st.boss.y);
    for (const r of fresh(st.rings)) {
      if (r.kind === 'slam') { if (r.big) play('big', r.x, r.y); else play('slam', !!r.heavy); }
      else if (r.kind === 'ember') play('ember', r.x, r.y);
      else if (r.kind === 'gale') play('gale', r.x, r.y);
      else if (r.kind === 'veil' && st.lvl === P.lvl) play('veil');
    }
    if (fresh(st.quakes).length) play('quake');
    for (const pr of fresh(st.proj)) play(pr.blade ? 'blade' : 'hexCast', pr.x, pr.y);
    for (const pr of P.proj) if (!(st.proj || []).includes(pr)) play(pr.blade ? 'bladeEnd' : 'hexBurst', pr.x, pr.y);
    for (const e of live) { if (e.act > 0 && !(e.__act > 0) && /^(dr|fg|sn)$/.test(e.type)) play('tele', e.type, e.x, e.y); if (e.pounce > .8 && !(e.__pn > .8)) play('pounce', e.x, e.y); e.__act = e.act; e.__pn = e.pounce; }
    // ---- banners: candles, the strepitus, braziers, slain bosses
    const bt = st.banner && st.banner.text;
    if (bt && bt !== P.banner) {
      if (/STREPITUS/.test(bt)) play('strepitus');
      else if (/CANDLE GOES OUT/.test(bt)) play('candle', 15 - STORY.candlesOut(st.depth));
      else if (/BRAZIER/.test(bt)) play('brazier', p.x, p.y);
      else if (/SLAIN|FALLS/.test(bt)) play('slain');
      else if (!/HIDDEN CANDLE/.test(bt)) play('banner');
    }
    // ---- death: timed to the souls-like sequence in story.js
    if (st.dying > 0) {
      const e = STORY.DEATH_T - st.dying, stg = e >= 2.4 ? 3 : e >= 2.1 ? 2 : e >= .9 ? 1 : 0;
      if (!(P.dying > 0)) { deathStage = -1; stopLine(now()); }
      while (deathStage < stg) { deathStage++; play('die' + deathStage); }
    }
    // ---- the score follows the run
    const chI = STORY.chOf(st.depth);
    if (chI !== M.ch) { M.ch = chI; setRoot(now()); }
    M.k = STORY.candlesOut(st.depth) / 15; M.dark = st.depth >= 16 ? 1 : 0; M.hp = st.dying ? 9 : st.hp;
    M.boss = st.boss && !st.boss.dead ? 1 : 0;
    const target = cl(live.length / 12, 0, 1) * .7 + (st.flow > 8 ? .2 : 0) + (st.bossIntro > 0 ? .5 : 0);
    M.inten = mix(M.inten, target, cl((rdt || .016) * .6, 0, 1));
    const mode = st.dying > 0 ? 'death' : M.mode === 'victory' && (cut || (ov && ov.kind === 'over')) ? 'victory' : cut ? 'cut' : ov ? 'menu' : 'game';
    M.mode = mode;
    const key = mode + M.ch + M.boss + Math.round(M.k * 15) + M.dark + muted;
    if (key !== mixKey || performance.now() - lastMix > 1500) { mixKey = key; lastMix = performance.now(); mixTo(now()); }
    Object.assign(P, { hp: st.hp, kills: st.kills, lvl: st.lvl, depth: st.depth, banner: bt, dying: st.dying, ovk: ov && ov.kind, ovp: ov && ov.pick, ovd: ov && ov.done, ovdur: ov && ov.dur,
      atk: p.atk, step: p.atk && p.atk.step, dash: p.dash, dj: p.dj, ground: p.ground, slam: p.slam, kick: p.kick, dropT: p.dropT, wax: st.runWax, hidden: st.hidden, bosses: st.bosses,
      proj: [...(st.proj || [])], vy: p.vy, ba, victory: st.victory, run: st.run, live: st.E.slice() });
  }
  function hud(ctx, W, H) {
    const msg = !ac ? 'PRESS ANY KEY FOR SOUND' : toast > 0 ? (muted ? 'SOUND OFF  ·  M' : 'SOUND ON  ·  M') : '';
    if (!msg) return;
    ctx.save(); ctx.font = '600 10px "IBM Plex Mono", ui-monospace, monospace'; ctx.textAlign = 'right'; ctx.fillStyle = `rgba(200,190,180,${!ac ? .55 : Math.min(1, toast) * .9})`;
    ctx.fillText(msg, W - 16, H - 14); ctx.restore();
  }
  async function render(dur, fn, sr = 44100) {
    const keep = { ac, out, comp, revIn, sfxB, musB, musF, ambB, voxB, driveB, duckG, noiseBuf, drone, pad, amb, muted, line, M: { ...M } };
    const oc = new OfflineAudioContext(2, Math.ceil(dur * sr), sr);
    ac = oc; muted = false; line = null; graph(); musB.gain.value = 1;
    try { fn(); } finally {
      ({ ac, out, comp, revIn, sfxB, musB, musF, ambB, voxB, driveB, duckG, noiseBuf, drone, pad, amb, muted, line } = keep); Object.assign(M, keep.M);
    }
    const buf = await oc.startRendering();
    return [buf.getChannelData(0), buf.getChannelData(1)];
  }
  const renderSfx = (name, args, dur) => render(dur, () => S[name](...(args || [])));
  const renderVoice = (who, text, maxDur) => render(maxDur + 2.5, () => speak(who, text, maxDur));
  function renderStem(chI, stem, bars) {
    const ch = CHM[chI], boss = stem === 'boss', bt = 60 / (ch.bpm * (boss ? 1.18 : 1)), L = bars * 4 * bt;
    return render(L + 6, () => {
      Object.assign(M, { ch: chI, k: .35, inten: stem === 'base' ? 0 : .9, boss: boss ? 1 : 0, mode: 'game', beat: 0, dark: 0 });
      drone = pad = amb = null;
      if (stem !== 'drums') { startMusic(true);
        drone.g.gain.cancelScheduledValues(0); drone.g.gain.value = boss ? .36 : .3; drone.f.frequency.value = boss ? 340 : 220;
        pad.g.gain.cancelScheduledValues(0); pad.g.gain.value = boss ? .2 : .26; pad.f.frequency.value = 1700;
        amb.g.gain.cancelScheduledValues(0); amb.g.gain.value = .08; drone.os.forEach(({ s, o }) => s.frequency.value = mf(ch.root + o)); }
      for (let i = 0; i < bars * 4 + 8; i++) { beat(i * bt, ch, bt, true, { stem: boss ? 'all' : stem }); M.beat++; if (stem !== 'drums' && i % 7 === 3) ambEvent(i * bt + .1); }
    }).then(d => ({ data: d, loop: L }));
  }
  return { watch, hud, init, log, speak, play, renderSfx, renderVoice, renderStem, CAST, get ctx() { return ac; }, get out() { return out; }, get muted() { return muted; } };
})();
window.AUDIO = AUDIO;
