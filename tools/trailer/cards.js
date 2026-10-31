const { chromium } = require('playwright');
const cards = [['c1','MOVE LIKE IT MATTERS','',54],['c2','FIVE WEAPONS. FIVE SKILLS.','',54],['c3','FOUR BOSSES','One hidden flame',60],['c4','WICKBEARER','Bring the hidden flame home',110],['c5','WISHLIST ON STEAM','Wickbearer · coming to Early Access',54]];
(async () => { const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  for (const [n,t,s,z] of cards) { await p.goto('file://' + process.argv[2] + '?t=' + encodeURIComponent(t) + '&s=' + encodeURIComponent(s) + '&z=' + z); await p.waitForTimeout(1200); await p.screenshot({ path: n + '.png' }); }
  await b.close(); })();
