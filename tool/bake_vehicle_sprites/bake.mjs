// Bakes the four vehicle GLBs into nav sprite sheets:
//   assets/vehicles/<name>_nav.png  (16x12 grid, 192 frames of 160px:
//   48 headings x 4 animation phases, frame 0 = nose up, clockwise)
//
// Usage:  npm install && npm run bake            (all vehicles)
//         node bake.mjs vw_bus mercedes_taxi     (subset)
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../..');
const outDir = path.join(repoRoot, 'assets', 'vehicles');

// Per-vehicle bake tuning. yawOffsetDeg turns the model so its nose points
// screen-up at heading 0 (glTF convention is nose +Z, which faces the
// camera in our rig, hence the default 180).
const VEHICLES = {
  vw_bus: {},
  mercedes_taxi: {},
  vespa_rider: {},
  desert_camel: {},
};

const MIME = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.glb': 'model/gltf-binary',
  '.json': 'application/json',
};

function startServer() {
  const server = http.createServer((req, res) => {
    const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    let file;
    if (urlPath === '/' || urlPath === '/harness.html') {
      file = path.join(here, 'harness.html');
    } else if (urlPath.startsWith('/node_modules/')) {
      file = path.join(here, urlPath);
    } else if (urlPath.startsWith('/assets/')) {
      file = path.join(repoRoot, urlPath);
    }
    if (!file || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      res.writeHead(404).end('not found');
      return;
    }
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream',
    });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

async function launchBrowser() {
  const attempts = [
    ['--use-gl=angle'],
    ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'],
  ];
  let lastErr;
  for (const args of attempts) {
    const browser = await puppeteer.launch({ headless: true, args });
    const page = await browser.newPage();
    const hasWebgl = await page.evaluate(() => {
      const canvas = document.createElement('canvas');
      return !!(canvas.getContext('webgl2') || canvas.getContext('webgl'));
    });
    await page.close();
    if (hasWebgl) return browser;
    lastErr = new Error(`no WebGL context with args ${args.join(' ')}`);
    await browser.close();
  }
  throw lastErr;
}

const names = process.argv.slice(2).length
  ? process.argv.slice(2)
  : Object.keys(VEHICLES);
for (const name of names) {
  if (!(name in VEHICLES)) {
    console.error(`unknown vehicle "${name}" (know: ${Object.keys(VEHICLES)})`);
    process.exit(1);
  }
}

const server = await startServer();
const port = server.address().port;
const browser = await launchBrowser();

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 800, height: 600, deviceScaleFactor: 1 });
  page.on('console', (m) => console.log(`  [page] ${m.text()}`));
  page.on('pageerror', (e) => console.error(`  [page error] ${e.message}`));
  await page.goto(`http://127.0.0.1:${port}/harness.html`);
  await page.waitForFunction('window.__harnessReady === true');

  for (const name of names) {
    console.log(`baking ${name}...`);
    const dataUrl = await page.evaluate(
      (glbUrl, overrides) => window.bakeVehicle({ glbUrl, ...overrides }),
      `/assets/${name}.glb`,
      VEHICLES[name],
    );
    const png = Buffer.from(dataUrl.split(',')[1], 'base64');
    const out = path.join(outDir, `${name}_nav.png`);
    fs.writeFileSync(out, png);
    console.log(`  wrote ${path.relative(repoRoot, out)} (${(png.length / 1024).toFixed(0)} KB)`);
  }
} finally {
  await browser.close();
  server.close();
}
console.log('done');
