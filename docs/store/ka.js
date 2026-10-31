const { chromium } = require('playwright');
const jobs = [['keyart-4k',3840,2160,1,''],['capsule-header',920,430,1,'50% 40%'],['capsule-small',462,174,1,'50% 35%'],['capsule-main',1232,706,1,''],['capsule-vertical',748,896,1,'52% 50%'],['library-capsule',600,900,1,'52% 50%'],['library-hero',3840,1240,0,'50% 35%']];
(async () => { const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 3900, height: 2200 } });
  for (const [n,w,h,logo,pos] of jobs) { await p.goto('file://' + process.argv[2] + '?w='+w+'&h='+h+'&logo='+logo+'&pos='+encodeURIComponent(pos)); await p.waitForTimeout(1500);
    await p.locator('#c').screenshot({ path: process.argv[3] + '/' + n + '.png' }); }
  await b.close(); })();
