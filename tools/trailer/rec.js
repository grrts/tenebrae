const { chromium } = require('playwright');
const [,, file, query, secs, mode, out] = process.argv;
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 1152, height: 720 }, recordVideo: { dir: out, size: { width: 1152, height: 720 } } });
  await ctx.addInitScript(() => { try { localStorage.setItem('wickbearer.codex', JSON.stringify({"norrow":1,"hild":1,"hush":1,"strepitus":1,"umber":1,"dawn":1,"place_0":1,"place_1":1,"place_2":1,"place_3":1,"foe_0":1,"foe_1":1,"foe_2":1,"foe_3":1,"foe_4":1,"foe_5":1,"foe_6":1,"elite":1,"boss_0":1,"boss_1":1,"boss_2":1,"boss_3":1})); } catch (e) {} });
  const p = await ctx.newPage(); const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.goto('file://' + file + (query ? '?' + query : ''));
  await p.addStyleTag({ content: '.keys{display:none!important} body{background:#000} #cv-demo{width:1152px!important;height:720px!important}' });
  await p.mouse.click(500, 300);
  const end = Date.now() + secs * 1000; let i = 0;
  const tap = async (k, ms = 70) => { await p.keyboard.down(k); await p.waitForTimeout(ms); await p.keyboard.up(k); };
  if (mode !== 'story') { for (let k = 0; k < 10; k++) { await p.keyboard.press('Enter'); await p.waitForTimeout(120); await tap('KeyJ'); await p.waitForTimeout(120); } }
  while (Date.now() < end) {
    i++;
    if (mode === 'story') { await p.waitForTimeout(1500); await tap('KeyJ'); continue; }
    if (mode === 'move') {
      const dir = (Math.floor(i / 6) % 2) ? 'KeyA' : 'KeyD';
      await p.keyboard.down(dir);
      await tap('Space', 160); await p.waitForTimeout(120); await tap('Space', 100);
      await tap('KeyJ'); await tap('KeyJ'); await tap('ShiftLeft');
      await p.keyboard.down('KeyS'); await tap('KeyJ'); await p.keyboard.up('KeyS');
      await p.keyboard.up(dir); await tap('KeyJ'); await tap('KeyJ'); await tap('KeyJ');
    }
    if (mode === 'skills') {
      await p.evaluate(() => { if (window.__st) window.__st.skill = 1; }); await p.waitForTimeout(80);
      await tap('KeyQ'); for (let k = 0; k < 6; k++) await tap('KeyJ', 90);
      if (i % 3 === 0) await p.evaluate(() => { const s = window.__st; const w = ['katana', 'greatsword', 'spear', 'daggers', 'sickle']; s.weapon = w[(w.indexOf(s.weapon) + 1) % 5]; });
    }
    if (mode === 'boss' || mode === 'move' || mode === 'skills') await p.evaluate(() => { if (window.__st) window.__st.hp = window.__st.maxHp; });
    if (mode === 'boss') { for (let k = 0; k < 4; k++) await tap('KeyJ', 90); await tap('Space', 140); await tap('KeyJ'); await p.keyboard.down('KeyS'); await tap('KeyJ'); await p.keyboard.up('KeyS'); if (i % 4 === 0) { await p.evaluate(() => { if (window.__st) { window.__st.skill = 1; window.__st.hp = window.__st.maxHp; } }); await tap('KeyQ'); } }
  }
  await ctx.close(); await b.close(); console.log(out, errs.join('|') || 'ok');
})();
