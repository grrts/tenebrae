// Renders the browser build's procedural audio (web/audio.js) to OGG files for the Godot build:
// sound effects, the score's loop stems, and one gibberish voice clip per spoken line in src/story.gd.
// Run from the repo root: node tools/render_audio.js   (needs Playwright's Chromium and ffmpeg)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), crypto = require('crypto'), { execFileSync } = require('child_process');
const ROOT = path.resolve(__dirname, '..'), OUT = path.join(ROOT, 'audio'), SR = 44100;

const SFX = {
  hit: ['hit', [false, 0, 0, false]], hit_crit: ['hit', [true, 0, 0, false]],
  hurt: ['hurt'], heal: ['heal'], jump: ['jump'], djump: ['djump'], wall: ['wall'], drop: ['drop'], land: ['land', [.6]], step: ['step'],
  dash: ['dash'], slam_start: ['slamStart'], slam: ['slam', [false]], slam_heavy: ['slam', [true]], wax: ['wax', [0]], level: ['level', [], 3],
  hex_cast: ['hexCast'], hex_burst: ['hexBurst'], roar: ['roar', [], 3], big: ['big'], wind: ['wind'], quake: ['quake'], boss_death: ['bossDeath', [], 7.5],
  strepitus: ['strepitus', [], 5], candle_hi: ['candle', [14], 6], candle_mid: ['candle', [8], 6], candle_lo: ['candle', [2], 6], brazier: ['brazier'],
  ember: ['ember'], gale: ['gale'], veil: ['veil'], revive: ['revive', [], 4], banner: ['banner'], slain: ['slain', [], 3.5],
  ui_open: ['uiOpen'], ui_move: ['uiMove'], ui_ok: ['uiOk'], ui_leave: ['uiLeave'], over: ['over', [false], 7], over_victory: ['over', [true], 7.5],
  die0: ['die0'], die1: ['die1'], die2: ['die2'], die3: ['die3', [], 9.5], shot: ['shot'], flash_red: ['flash', [true]], flash_white: ['flash', [false]],
  rumble: ['rumble', [.5]], card: ['card', ['gold'], 7], eyes: ['eyes'], focus: ['focus'], streak: ['streak'], anvil: ['anvil'],
  pounce: ['pounce'], blade: ['blade'], blade_end: ['bladeEnd']
};
for (const w of ['katana', 'spear', 'greatsword', 'daggers', 'sickle']) { SFX['swing_' + w] = ['swing', [w, 0]]; SFX['swing_' + w + '_big'] = ['swing', [w, 2]]; }
for (const t of ['sh', 'bat', 'br', 'sp', 'dr', 'fg', 'sn']) { SFX['kill_' + t] = ['kill', [t, 0, 0, false]]; SFX['spawn_' + t] = ['spawn', [t, 0, 0, false]]; }
for (const t of ['dr', 'fg', 'sn']) SFX['tele_' + t] = ['tele', [t, 0, 0]];

function lines() {
  const src = fs.readFileSync(path.join(ROOT, 'src/story.gd'), 'utf8'), out = new Map();
  for (const m of src.matchAll(/\{([^{}]*"text":\s*"((?:[^"\\]|\\.)*)"[^{}]*)\}/g)) {
    const who = (m[1].match(/"who":\s*"([^"]*)"/) || [])[1] || null, text = JSON.parse('"' + m[2] + '"');
    out.set(crypto.createHash('md5').update(text, 'utf8').digest('hex').slice(0, 10), { who, text });
  }
  return out;
}
function writeOgg(file, L, Rr, q = 4) {
  const n = L.length, b = Buffer.alloc(44 + n * 4);
  b.write('RIFF', 0); b.writeUInt32LE(36 + n * 4, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(2, 22);
  b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 4, 28); b.writeUInt16LE(4, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) { b.writeInt16LE(Math.round(Math.max(-1, Math.min(1, L[i])) * 32767), 44 + i * 4); b.writeInt16LE(Math.round(Math.max(-1, Math.min(1, Rr[i])) * 32767), 46 + i * 4); }
  const tmp = file + '.wav'; fs.writeFileSync(tmp, b);
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', String(q), file]); fs.unlinkSync(tmp);
}
const trim = ([L, Rr]) => { let e = L.length; while (e > 1000 && Math.abs(L[e - 1]) < 2e-4 && Math.abs(Rr[e - 1]) < 2e-4) e--; e = Math.min(L.length, e + 2000); return [L.slice(0, e), Rr.slice(0, e)]; };

(async () => {
  for (const d of ['sfx', 'music', 'vo']) fs.mkdirSync(path.join(OUT, d), { recursive: true });
  const b = await chromium.launch(), pg = await b.newPage();
  pg.on('pageerror', e => console.error('page error', e.message));
  await pg.setContent('<html><body></body></html>');
  await pg.addScriptTag({ content: 'const STORY = null;\n' + fs.readFileSync(path.join(ROOT, 'web/audio.js'), 'utf8') });
  const get = async (expr) => { const r = await pg.evaluate(async (ex) => { const d = await eval(ex); const a = d.data || d; const enc = f => btoa(String.fromCharCode(...new Uint8Array(f.buffer))).toString();
    const chunk = f => { let s = ''; const u = new Uint8Array(f.buffer); for (let i = 0; i < u.length; i += 32768) s += String.fromCharCode(...u.subarray(i, i + 32768)); return btoa(s); };
    return { l: chunk(a[0]), r: chunk(a[1]), loop: d.loop }; }, expr);
    const f = s => { const buf = Buffer.from(s, 'base64'); return new Float32Array(buf.buffer, buf.byteOffset, buf.length / 4); };
    return { L: f(r.l), R: f(r.r), loop: r.loop }; };
  let n = 0;
  for (const [name, [fn, args = [], dur = 2.5]] of Object.entries(SFX)) {
    const r = await get(`AUDIO.renderSfx(${JSON.stringify(fn)}, ${JSON.stringify(args)}, ${dur})`);
    const [L, Rr] = trim([r.L, r.R]); writeOgg(path.join(OUT, 'sfx', name + '.ogg'), L, Rr); n++;
  }
  console.log('sfx', n);
  for (let ch = 0; ch < 4; ch++) for (const stem of ['base', 'drums', 'boss']) {
    const r = await get(`AUDIO.renderStem(${ch}, '${stem}', 8)`), Ln = Math.round(r.loop * SR), F = Math.round(3 * SR);
    // seamless loop: the tail past the loop point crossfades into the start
    const L = r.L.slice(0, Ln), Rr = r.R.slice(0, Ln);
    for (let i = 0; i < F; i++) { const k = i / F, a = Math.sqrt(k), z = Math.sqrt(1 - k); L[i] = L[i] * a + r.L[Ln + i] * z; Rr[i] = Rr[i] * a + r.R[Ln + i] * z; }
    writeOgg(path.join(OUT, 'music', `ch${ch}_${stem}.ogg`), L, Rr, 3);
  }
  console.log('music 12');
  const V = lines(); const keep = new Set();
  for (const [key, { who, text }] of V) {
    const r = await get(`AUDIO.renderVoice(${JSON.stringify(who)}, ${JSON.stringify(text)}, ${1.6 + text.length * .045})`);
    const [L, Rr] = trim([r.L, r.R]); writeOgg(path.join(OUT, 'vo', key + '.ogg'), L, Rr, 3); keep.add(key + '.ogg');
  }
  for (const f of fs.readdirSync(path.join(OUT, 'vo'))) if (f.endsWith('.ogg') && !keep.has(f)) fs.unlinkSync(path.join(OUT, 'vo', f));
  console.log('voice lines', V.size);
  await b.close();
})();
