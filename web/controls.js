/* ---------- input: keyboard, mouse, gamepad, pause and rebinding ---------- */
// Keys are physical codes (e.code), so WASD stays under the same fingers on AZERTY and QWERTZ.
// Two full hands work out of the box: WASD + Space / J / K (or the mouse), and arrows + Z / X / C.
const ACTIONS = ['left', 'right', 'up', 'down', 'jump', 'attack', 'dash', 'skill'];
const DEFAULT_KEYS = {
  left: ['KeyA', 'ArrowLeft'], right: ['KeyD', 'ArrowRight'], up: ['KeyW', 'ArrowUp'], down: ['KeyS', 'ArrowDown'],
  jump: ['Space', 'KeyZ'], attack: ['KeyJ', 'KeyX', 'Mouse0'], dash: ['ShiftLeft', 'KeyK', 'KeyC', 'ShiftRight', 'Mouse2'], skill: ['KeyQ', 'KeyL'],
};
const RESERVED = ['Escape', 'Enter', 'NumpadEnter', 'Tab', 'F1', 'F5', 'F11', 'F12', 'MetaLeft', 'MetaRight'];
const store = (k, v) => { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } };
const BIND = (() => { try { return JSON.parse(store('wickbearer.keys') || '{}') || {}; } catch (e) { return {}; } })();
let upJumps = store('wickbearer.upjump') !== '0';
let KEYS = {};
function rebuildKeys() {
  const mine = new Set(Object.values(BIND));
  KEYS = {};
  for (const a of ACTIONS) {
    const d = DEFAULT_KEYS[a], first = BIND[a] || d[0];
    // a key you bound yourself always wins over a default somewhere else
    KEYS[a] = [first, ...d.slice(1).filter(c => c !== first && !mine.has(c))];
  }
  store('wickbearer.keys', JSON.stringify(BIND)); store('wickbearer.upjump', upJumps ? '1' : '0');
  const el = document.getElementById('keys'); if (el) el.innerHTML = keysLine();
}
const KEYNAME = { Space: 'SPACE', ArrowLeft: '←', ArrowRight: '→', ArrowUp: '↑', ArrowDown: '↓', ShiftLeft: 'SHIFT', ShiftRight: 'R-SHIFT',
  ControlLeft: 'CTRL', ControlRight: 'R-CTRL', AltLeft: 'ALT', AltRight: 'R-ALT', Mouse0: 'LMB', Mouse1: 'MMB', Mouse2: 'RMB', Mouse3: 'MB4', Mouse4: 'MB5',
  Backquote: '`', Minus: '-', Equal: '=', BracketLeft: '[', BracketRight: ']', Backslash: '\\', Semicolon: ';', Quote: "'", Comma: ',', Period: '.', Slash: '/',
  Backspace: 'BKSP', CapsLock: 'CAPS', Enter: 'ENTER' };
const keyName = c => KEYNAME[c] || c.replace(/^(Key|Digit)/, '').replace(/^Numpad/, 'NUM ').toUpperCase();
const keyLabel = a => keyName(KEYS[a][0]);
const keysList = a => KEYS[a].filter(c => c !== 'ShiftRight').map(keyName).join(' / ');
function keysLine() {
  const b = s => `<b>${s}</b>`;
  return `${b(keyLabel('left') + ' ' + keyLabel('right'))} or ${b('← →')} move · ${b(keysList('jump'))}${upJumps ? ' or ' + b(keyLabel('up')) : ''} jump · ` +
    `${b(keysList('attack'))} attack (hold to keep swinging) · ${b(keysList('dash'))} dash · ${b(keysList('skill'))} weapon skill when the meter is full · ${b(keyLabel('down'))} + attack in air: slam · ` +
    `${b(keyLabel('down'))} + jump: drop · ${b('TAB')} the Codex · ${b('ESC')} pause and rebind · controller works too`;
}

const held = new Set(), tapped = new Set(), swallow = new Set(), IN = {}, PR = {}, prevIN = {};
const MOUSE = { x: .5, y: .5, aim: false };
let lastHorz = 0, rebind = null, pendingRebind = null;
const bound = c => ACTIONS.some(a => KEYS[a].includes(c));
function press(code, e) {
  if (rebind) { if (e) e.preventDefault(); pendingRebind = code; swallow.add(code); return; }
  if (swallow.has(code)) return;
  if (!held.has(code)) tapped.add(code);
  held.add(code);
  if (KEYS.left.includes(code)) lastHorz = -1;
  if (KEYS.right.includes(code)) lastHorz = 1;
}
addEventListener('keydown', e => {
  if (e.ctrlKey || e.metaKey) return;
  if (bound(e.code) || e.code === 'Escape' || e.code === 'KeyP' || e.code === 'Enter' || e.code === 'Backspace') e.preventDefault();
  if (e.repeat) return;
  press(e.code, e);
}, true);
addEventListener('keyup', e => { held.delete(e.code); swallow.delete(e.code); });
addEventListener('blur', () => { held.clear(); swallow.clear(); });
addEventListener('mousedown', e => {
  const cv = e.target && e.target.id === 'cv-demo' ? e.target : null; if (!cv && !rebind) return;
  if (CTRL.menu && CTRL.menu.why === 'focus' && !rebind) { CTRL.resume(); swallow.add('Mouse' + e.button); return; }
  MOUSE.aim = true; press('Mouse' + e.button, e);
});
addEventListener('mouseup', e => { held.delete('Mouse' + e.button); swallow.delete('Mouse' + e.button); });
addEventListener('mousemove', e => {
  const cv = document.getElementById('cv-demo'); if (!cv) return;
  const r = cv.getBoundingClientRect(); MOUSE.x = (e.clientX - r.left) / r.width; MOUSE.y = (e.clientY - r.top) / r.height;
});
addEventListener('contextmenu', e => { if (e.target && e.target.id === 'cv-demo') e.preventDefault(); });

function pollInput() {
  const pad = (navigator.getGamepads ? [...navigator.getGamepads()] : []).find(g => g);
  const b = i => !!(pad && pad.buttons[i] && pad.buttons[i].pressed), ax = i => pad ? pad.axes[i] || 0 : 0;
  const now = {
    left: b(14) || ax(0) < -.4, right: b(15) || ax(0) > .4, up: b(12) || ax(1) < -.5, down: b(13) || ax(1) > .5,
    jump: b(0), attack: b(2), dash: b(5) || b(7) || b(1), skill: b(3) };
  const any = (codes, set) => codes.some(c => set.has(c));
  for (const k of ACTIONS) {
    const tap = any(KEYS[k], tapped);
    IN[k] = now[k] || any(KEYS[k], held) || tap; PR[k] = (IN[k] && !prevIN[k]) || tap; prevIN[k] = IN[k];
  }
  // on the keyboard the last direction pressed wins, so A+D never stalls you
  IN.dir = IN.left && IN.right ? lastHorz : (IN.right ? 1 : 0) - (IN.left ? 1 : 0);
  if (IN.dir && !(IN.left && IN.right)) lastHorz = IN.dir;
  // menus: Enter, Space, jump or attack confirm; the Up alias for jump does not
  PR.ok = PR.jump || PR.attack || tapped.has('Enter') || tapped.has('NumpadEnter') || tapped.has('Space');
  PR.back = tapped.has('Backspace') || (b(1) && !prevIN.padB);
  PR.pause = tapped.has('Escape') || (tapped.has('KeyP') && !bound('KeyP')) || (b(9) && !prevIN.padStart);
  PR.pick = ['Digit1', 'Digit2', 'Digit3', 'Numpad1', 'Numpad2', 'Numpad3'].findIndex(c => tapped.has(c)) % 3;
  if (PR.attack || PR.dash) MOUSE.aim = tapped.has('Mouse0') || tapped.has('Mouse2');
  prevIN.padB = b(1); prevIN.padStart = b(9);
  if (upJumps) { const u = any(KEYS.up, tapped) || (IN.up && !prevIN.upJ); IN.jump = IN.jump || IN.up; PR.jump = PR.jump || u; prevIN.upJ = IN.up; }
  tapped.clear();
}
// which way the mouse is from the player, as -1 / 1, when the last swing or dash came from the mouse
function mouseSide(st, px, W) {
  if (!MOUSE.aim) return 0;
  return MOUSE.x * W > (px - st.cam.x) * ZM + W / 2 ? 1 : -1;
}

/* pause menu and the controls page, drawn over the arena */
const CTRL = (() => {
  const PAUSE = ['RESUME', 'CONTROLS', 'RESTART RUN'];
  const ROWS = [['left', 'MOVE LEFT'], ['right', 'MOVE RIGHT'], ['up', 'UP'], ['down', 'DOWN · DROP, SLAM'], ['jump', 'JUMP'], ['attack', 'ATTACK'], ['dash', 'DASH'], ['skill', 'WEAPON SKILL'],
    ['upjump', 'UP ALSO JUMPS'], ['reset', 'RESET TO DEFAULTS'], ['back', 'BACK']];
  const api = { menu: null };
  // while a menu is up the arena sees no presses, and no held swing or dash leaks through
  const clearPR = () => { for (const k in PR) PR[k] = false; PR.pick = -1; IN.attack = IN.dash = false; };
  api.clear = () => { clearPR(); return false; };
  api.resume = () => { api.menu = null; rebind = null; };
  api.open = (st, why) => { api.menu = { page: 'pause', sel: 0, why, t: 0 }; };
  // returns true while the game should run this frame
  api.step = (st, rdt) => {
    const m = api.menu;
    if (!m) {
      const playing = !st.cut && !(st.ov && st.ov.kind === 'over');
      if (playing && !document.hasFocus()) { api.open(st, 'focus'); clearPR(); return false; }
      if (playing && PR.pause) { api.open(st, 'key'); clearPR(); return false; }
      return true;
    }
    m.t += rdt;
    if (rebind) {
      if (pendingRebind) {
        const c = pendingRebind; pendingRebind = null;
        if (c !== 'Escape' && !RESERVED.includes(c)) {
          for (const a of ACTIONS) if (BIND[a] === c && a !== rebind) delete BIND[a];
          if (c === DEFAULT_KEYS[rebind][0]) delete BIND[rebind]; else BIND[rebind] = c;
          rebuildKeys();
        }
        rebind = null;
      }
      clearPR(); return false;
    }
    const list = m.page === 'pause' ? PAUSE : ROWS, n = list.length;
    if (PR.up || PR.left && m.page === 'pause') m.sel = (m.sel + n - 1) % n;
    if (PR.down || PR.right && m.page === 'pause') m.sel = (m.sel + 1) % n;
    if (m.page === 'pause') {
      if (PR.pause || PR.back) api.resume();
      else if (PR.ok && m.t > .15) {
        if (m.sel === 0) api.resume();
        else if (m.sel === 1) { m.page = 'controls'; m.sel = 0; }
        else { st.cut = null; st.cutPend = 0; newRun(st); api.resume(); }
      }
    } else {
      if (PR.pause || PR.back) { m.page = 'pause'; m.sel = 1; }
      else if (PR.ok) {
        const id = ROWS[m.sel][0];
        if (ACTIONS.includes(id)) { rebind = id; pendingRebind = null; for (const c of held) swallow.add(c); }
        else if (id === 'upjump') { upJumps = !upJumps; rebuildKeys(); }
        else if (id === 'reset') { for (const a of ACTIONS) delete BIND[a]; upJumps = true; rebuildKeys(); }
        else { m.page = 'pause'; m.sel = 1; }
      }
    }
    clearPR(); return false;
  };
  api.draw = (ctx, W, H) => {
    const m = api.menu; if (!m) return;
    const txt = (s, x, y, size, col, align = 'center') => { ctx.font = `600 ${size}px ${MONO}`; ctx.textAlign = align; ctx.lineWidth = 4; ctx.strokeStyle = '#000'; ctx.strokeText(s, x, y); ctx.fillStyle = col; ctx.fillText(s, x, y); };
    ctx.save(); ctx.fillStyle = 'rgba(7,5,6,.78)'; ctx.fillRect(0, 0, W, H);
    if (m.page === 'pause') {
      txt('PAUSED', W / 2, H * .3, 40, '#f3ebe0');
      if (m.why === 'focus') txt(document.hasFocus() ? 'PRESS ESC OR ENTER TO PLAY' : 'CLICK THE GAME TO PLAY', W / 2, H * .3 + 34, 14, C.gold);
      PAUSE.forEach((s, i) => { const y = H * .46 + i * 40, sel = i === m.sel;
        if (sel) { ctx.fillStyle = 'rgba(229,56,59,.22)'; ctx.fillRect(W / 2 - 150, y - 26, 300, 36); ctx.fillStyle = C.crimson; ctx.fillRect(W / 2 - 150, y - 26, 3, 36); }
        txt(s, W / 2, y, 18, sel ? '#f3ebe0' : '#9a9289'); });
      txt(`↑ ↓  CHOOSE     ENTER / ${keyLabel('attack')}  SELECT     ESC  RESUME`, W / 2, H - 30, 11, '#6f675f');
    } else {
      txt('CONTROLS', W / 2, 74, 32, '#f3ebe0');
      txt('KEYBOARD AND MOUSE · SAVED IN THIS BROWSER · A CONTROLLER ALWAYS WORKS', W / 2, 100, 11, '#9a9289');
      ROWS.forEach(([id, name], i) => { const y = 146 + i * 36, sel = i === m.sel, x0 = W / 2 - 300;
        if (sel) { ctx.fillStyle = 'rgba(229,56,59,.22)'; ctx.fillRect(x0, y - 23, 600, 32); ctx.fillStyle = C.crimson; ctx.fillRect(x0, y - 23, 3, 32); }
        txt(name, x0 + 18, y, 15, sel ? '#f3ebe0' : '#9a9289', 'left');
        let v = '';
        if (ACTIONS.includes(id)) v = rebind === id ? (Math.floor(m.t * 3) % 2 ? 'PRESS A KEY…' : '') : keysList(id);
        else if (id === 'upjump') v = upJumps ? 'ON' : 'OFF';
        txt(v, x0 + 582, y, 15, rebind === id ? C.gold : sel ? C.gold : '#f3ebe0', 'right'); });
      txt(rebind ? 'PRESS A KEY OR MOUSE BUTTON · ESC CANCELS' : `↑ ↓  CHOOSE     ENTER  REBIND / TOGGLE     ESC  BACK`, W / 2, H - 30, 11, rebind ? C.gold : '#6f675f');
    }
    ctx.restore();
  };
  return api;
})();
rebuildKeys();
