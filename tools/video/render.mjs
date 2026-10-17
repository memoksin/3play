// Frame-exact render of a pitch-video segment (tools/video/<segment>.html) to export/video/<segment>.mp4.
// Headless Chrome (no window) via the DevTools protocol, viewport exactly 1920x1080 @1x; frame N = renderAt(N / fps),
// captured as PNG into export/video/frames/<segment>/%05d.png, then encoded with ffmpeg (H.264, CRF 16, yuv420p).
// Pages are served by a local http server bound to 127.0.0.1 (WebGL refuses file:// images); no network access.
//
// Usage: node tools/video/render.mjs <segment>                 full render + mp4
//        node tools/video/render.mjs <segment> --still 1.5,3.2  only PNG stills at those times (iteration), no mp4
//        node tools/video/render.mjs <segment> --resume         keep export/video/frames/<segment>/, render only missing frames
//        node tools/video/render.mjs film --clips /abs/dir        serve Godot clip PNGs from another folder (default
//                                                                 export/video/clips) at /__clips/ and pass ?clips= to the page
// renderAt(t) may return a Promise (film.html loads clip frames); the capture waits for it.
import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync, readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve, extname, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..', '..');
const seg = process.argv[2];
if (!seg || !existsSync(join(here, `${seg}.html`))) { console.error('usage: node tools/video/render.mjs <segment> [--still t1,t2]'); process.exit(2); }
const si = process.argv.indexOf('--still');
const stills = si > 0 ? process.argv[si + 1].split(',').map(Number) : null;
const ci = process.argv.indexOf('--clips');
const clipsDir = ci > 0 ? resolve(process.argv[ci + 1]) : null;
const resume = process.argv.includes('--resume');
const W = 1920, H = 1080;
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.png': 'image/png', '.ttf': 'font/ttf', '.json': 'application/json' };
const server = createServer((req, res) => {
  const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const base = clipsDir && path.startsWith('/__clips/') ? clipsDir : root;
  const p = normalize(join(base, base === root ? path : path.slice('/__clips/'.length)));
  if (!p.startsWith(base) || !existsSync(p) || !statSync(p).isFile()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'content-type': MIME[extname(p)] || 'application/octet-stream', 'cache-control': 'no-store' });
  res.end(readFileSync(p));
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const url = `http://127.0.0.1:${server.address().port}/tools/video/${seg}.html${clipsDir ? '?clips=/__clips/' : ''}`;

const prof = mkdtempSync(join(tmpdir(), 'vid-'));
const chrome = spawn(CHROME, ['--headless=new', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist',
  '--hide-scrollbars', '--mute-audio', '--no-first-run', '--remote-debugging-port=0', `--user-data-dir=${prof}`, 'about:blank'], { stdio: 'ignore' });

async function main() {
  let port;
  for (let i = 0; i < 100 && !port; i++) { await sleep(100); try { port = readFileSync(join(prof, 'DevToolsActivePort'), 'utf8').split('\n')[0]; } catch {} }
  let list;
  for (let i = 0; i < 50 && !list; i++) { try { list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json(); } catch { await sleep(200); } }
  const page = list.find((t) => t.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener('open', r, { once: true }));
  let id = 0; const pending = new Map();
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
    if (m.method === 'Runtime.exceptionThrown') console.log('PAGE EXCEPTION', m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text);
    if (m.method === 'Runtime.consoleAPICalled' && ['error', 'warning'].includes(m.params.type)) console.log('PAGE', m.params.type, m.params.args.map((x) => x.value || x.description).join(' ').slice(0, 300));
  });
  const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
  const evaluate = async (expression) => {
    const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (r.result?.exceptionDetails) throw new Error(r.result.exceptionDetails.exception?.description || r.result.exceptionDetails.text);
    return r.result?.result?.value;
  };
  await send('Page.enable'); await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: 1, mobile: false });
  await send('Page.navigate', { url });
  let ok = false;
  for (let i = 0; i < 300 && !ok; i++) {
    await sleep(100);
    const err = await evaluate('document.documentElement.dataset.error || ""');
    if (err) throw new Error('page: ' + err);
    ok = await evaluate('document.documentElement.dataset.ready === "1"');
  }
  if (!ok) throw new Error('page not ready');
  const info = await evaluate('window.SEGMENT');
  const frames = stills ? stills.map((t) => Math.round(t * info.fps)) : [...Array(info.frames).keys()];
  const dir = join(root, 'export', 'video', stills ? 'stills' : 'frames', seg);
  if (!(resume && !stills)) rmSync(dir, { recursive: true, force: true });   // script-owned output: start clean
  mkdirSync(dir, { recursive: true });
  const t0 = Date.now();
  for (const [k, f] of frames.entries()) {
    if (resume && !stills && existsSync(join(dir, `${String(f).padStart(5, '0')}.png`))) continue;
    // render, then wait one animation frame so the compositor has presented it before the capture
    await evaluate(`Promise.resolve(window.renderAt(${f} / ${info.fps})).then(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(() => r(1)))))`);
    const shot = await send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: W, height: H, scale: 1 } });
    const name = stills ? `${seg}_t${(f / info.fps).toFixed(3)}.png` : `${String(f).padStart(5, '0')}.png`;
    writeFileSync(join(dir, name), Buffer.from(shot.result.data, 'base64'));
    if (k % 30 === 0 || stills) process.stdout.write(`\r${k + 1}/${frames.length} frames  ${((Date.now() - t0) / 1000).toFixed(0)}s   `);
  }
  console.log();
  ws.close();
  if (info.cues) writeFileSync(join(root, 'export', 'video', `${seg}_cues.json`), JSON.stringify(info.cues, null, 1));
  if (info.audio) writeFileSync(join(root, 'export', 'video', `${seg}_audio.json`), JSON.stringify(info.audio, null, 1));   // tools/video/mix.py
  if (stills) { console.log('stills in', dir); return; }
  const mp4 = join(root, 'export', 'video', `${seg}.mp4`);
  const ff = spawnSync('ffmpeg', ['-y', '-loglevel', 'error', '-framerate', String(info.fps), '-i', join(dir, '%05d.png'),
    '-c:v', 'libx264', '-crf', '16', '-preset', 'slow', '-pix_fmt', 'yuv420p', '-r', String(info.fps), mp4], { stdio: 'inherit' });
  if (ff.status !== 0) throw new Error('ffmpeg failed');
  console.log(`${mp4}  (${readdirSync(dir).length} frames)`);
}
main().catch((e) => { console.error(e); process.exitCode = 1; }).finally(() => {
  chrome.kill(); server.close();
  setTimeout(() => rmSync(prof, { recursive: true, force: true }), 500);
});
