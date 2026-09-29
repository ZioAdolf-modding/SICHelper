// Randarea short-ului: Chromium headless deseneaza fiecare cadru, ffmpeg face MP4-ul.
//   node render.cjs --stills 0.5,6.4,15     -> out/stills/t_<sec>.png
//   node render.cjs --cues                  -> out/cues.json (pentru audio.py)
//   node render.cjs                         -> out/video.mp4 (fara sunet), apoi out/sichelper-short.mp4 cu sunet
//   optiuni: --from 12 --to 22 (doar o bucata), --workers 4
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn, execFileSync } = require('child_process');

let chromium;
try { ({ chromium } = require('playwright')); } catch { ({ chromium } = require('/opt/node22/lib/node_modules/playwright')); }

const ROOT = path.resolve(__dirname, '..', '..');          // radacina repo-ului (logo-ul e in docs/logo)
const PAGE = '/media/short-needlicense/index.html';
const OUT = path.join(__dirname, 'out');
const args = process.argv.slice(2);
const opt = k => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : undefined; };
const has = k => args.includes(k);

function ffmpegPath() {
  if (process.env.FFMPEG) return process.env.FFMPEG;
  try { return execFileSync('python3', ['-c', 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())']).toString().trim(); } catch { return 'ffmpeg'; }
}

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.ttf': 'font/ttf', '.png': 'image/png', '.json': 'application/json' };
function serve() {
  return new Promise(res => {
    const srv = http.createServer((req, rsp) => {
      const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
      if (!p.startsWith(ROOT) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { rsp.writeHead(404); rsp.end(); return; }
      rsp.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' });
      fs.createReadStream(p).pipe(rsp);
    });
    srv.listen(0, '127.0.0.1', () => res(srv));
  });
}

async function openPage(browser, port) {
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  page.on('pageerror', e => console.error('pageerror:', e.message));
  page.on('console', m => { if (m.type() === 'error') console.error('console:', m.text()); });
  await page.goto(`http://127.0.0.1:${port}${PAGE}`);
  await page.evaluate(() => SHORT.ready);
  return page;
}
const grab = (page, t, type, q) => page.evaluate(([t, type, q]) => {
  SHORT.render(t);
  return document.getElementById('c').toDataURL(type, q).split(',')[1];
}, [t, type, q]);

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const srv = await serve();
  const port = srv.address().port;
  const browser = await chromium.launch({ args: ['--disable-web-security', '--font-render-hinting=none'] });
  try {
    if (has('--cues')) {
      const page = await openPage(browser, port);
      const cues = await page.evaluate(() => ({ T: SHORT.T, cues: SHORT.cues, duration: SHORT.DURATION }));
      fs.writeFileSync(path.join(OUT, 'cues.json'), JSON.stringify(cues, null, 1));
      console.log('cues:', cues.cues.length);
      return;
    }
    if (opt('--stills')) {
      const page = await openPage(browser, port);
      const dir = path.join(OUT, 'stills');
      fs.mkdirSync(dir, { recursive: true });
      for (const s of opt('--stills').split(',')) {
        const t = parseFloat(s);
        const t0 = Date.now();
        const b64 = await grab(page, t, 'image/png');
        const f = path.join(dir, `t_${t.toFixed(2)}.png`);
        fs.writeFileSync(f, Buffer.from(b64, 'base64'));
        console.log(f, (Date.now() - t0) + ' ms');
      }
      return;
    }
    // randarea completa
    const FPS = 30, from = parseFloat(opt('--from') || '0'), to = parseFloat(opt('--to') || '60');
    const n0 = Math.round(from * FPS), n1 = Math.round(to * FPS);
    const workers = parseInt(opt('--workers') || '4', 10);
    const out = path.join(OUT, has('--from') || has('--to') ? `part_${from}_${to}.mp4` : 'video.mp4');
    const ff = spawn(ffmpegPath(), ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
      '-c:v', 'libx264', '-preset', 'slow', '-crf', '19', '-maxrate', '9M', '-bufsize', '18M', '-pix_fmt', 'yuv420p', '-r', String(FPS), out], { stdio: ['pipe', 'inherit', 'inherit'] });
    const pages = await Promise.all(Array.from({ length: workers }, () => openPage(browser, port)));
    const ready = new Map();
    let next = n0, written = n0;
    const started = Date.now();
    const writeReady = async () => {
      while (ready.has(written)) {
        const buf = ready.get(written); ready.delete(written);
        if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
        written++;
        if (written % 60 === 0) {
          const el = (Date.now() - started) / 1000, done = written - n0, total = n1 - n0;
          console.log(`cadru ${written}/${n1}  ${(done / el).toFixed(1)} fps  ~${Math.round((total - done) / (done / el))} s ramase`);
        }
      }
    };
    await Promise.all(pages.map(async page => {
      while (next < n1) {
        const i = next++;
        while (i - written > workers * 6) await new Promise(r => setTimeout(r, 20));
        const b64 = await grab(page, i / FPS, 'image/jpeg', 0.95);
        ready.set(i, Buffer.from(b64, 'base64'));
        await writeReady();
      }
    }));
    await writeReady();
    ff.stdin.end();
    await new Promise(r => ff.on('close', r));
    console.log('video:', out);
    // sunetul, daca exista
    const wav = path.join(OUT, 'audio.wav');
    if (!has('--from') && !has('--to') && fs.existsSync(wav)) {
      const fin = path.join(OUT, 'sichelper-short.mp4');
      execFileSync(ffmpegPath(), ['-y', '-loglevel', 'error', '-i', out, '-i', wav, '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', fin]);
      console.log('final:', fin);
    }
  } finally {
    await browser.close();
    srv.close();
  }
})().catch(e => { console.error(e); process.exit(1); });
