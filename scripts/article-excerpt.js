#!/usr/bin/env node
// article-excerpt.js — screenshot a tight crop of the paragraph containing a
// highlighted phrase. Produces a PNG sized for use as a 9:16 overlay panel.
//
// Usage:
//   node scripts/article-excerpt.js <url> "<phrase>" <output.png>
//
// Options:
//   --width 900        Width of the excerpt panel in px (default: 900 — fits 9:16)
//   --padding 48       Padding around the highlighted element in px (default: 48)
//   --viewport 1080    Browser viewport width (default: 1080)

const puppeteer = require(
  require.resolve("puppeteer-core", {
    paths: [__dirname + "/../tools/hyperframes/node_modules"],
  })
);
const path = require("path");
const fs   = require("fs");

const args = process.argv.slice(2);
function getArg(flag, def) {
  const i = args.indexOf(flag);
  return i !== -1 ? args[i + 1] : def;
}

const [url, phrase, outputPath] = args.filter(a => !a.startsWith("--") && args[args.indexOf(a) - 1] !== "--width" && args[args.indexOf(a) - 1] !== "--padding" && args[args.indexOf(a) - 1] !== "--viewport");
const panelWidth   = parseInt(getArg("--width",    "900"), 10);
const padding      = parseInt(getArg("--padding",   "48"), 10);
const viewportW    = parseInt(getArg("--viewport", "1080"), 10);

if (!url || !phrase || !outputPath) {
  console.error("Usage: node scripts/article-excerpt.js <url> \"<phrase>\" <output.png> [--width 900] [--padding 48]");
  process.exit(1);
}

function findChrome() {
  const candidates = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium-browser",
  ];
  for (const c of candidates) if (fs.existsSync(c)) return c;
  return null;
}

(async () => {
  const chromePath = findChrome();
  if (!chromePath) {
    console.error("Chrome not found. Install Google Chrome.");
    process.exit(1);
  }

  const browser = await puppeteer.launch({
    executablePath: chromePath,
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox", `--window-size=${viewportW},1920`],
  });

  const page = await browser.newPage();
  await page.setViewport({ width: viewportW, height: 1920, deviceScaleFactor: 2 });

  console.log(`[excerpt] Loading ${url}…`);
  await page.goto(url, { waitUntil: "networkidle2", timeout: 30000 });
  await new Promise(r => setTimeout(r, 1500));

  // Inject highlight + find the element's bounding box
  const result = await page.evaluate((searchPhrase, pw, pad) => {
    function escapeRegex(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }

    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
    let targetNode = null;
    let node;
    while ((node = walker.nextNode())) {
      if (node.nodeValue.toLowerCase().includes(searchPhrase.toLowerCase())) {
        targetNode = node;
        break;
      }
    }
    if (!targetNode) return { found: false };

    // Wrap the phrase in a mark
    const re = new RegExp(escapeRegex(searchPhrase), "gi");
    const html = targetNode.nodeValue.replace(re,
      m => `<mark style="background:#FFD700;color:inherit;padding:1px 0;border-radius:2px;">${m}</mark>`
    );
    const span = document.createElement("span");
    span.innerHTML = html;
    targetNode.parentNode.replaceChild(span, targetNode);

    // Walk up to find a block-level container (p, h1-h6, li, blockquote, div with limited height)
    let el = span;
    while (el.parentElement) {
      const tag = el.parentElement.tagName.toLowerCase();
      const rect = el.parentElement.getBoundingClientRect();
      if (["p","h1","h2","h3","h4","h5","h6","li","blockquote"].includes(tag) || rect.height < 400) {
        el = el.parentElement;
        break;
      }
      el = el.parentElement;
    }

    el.scrollIntoView({ block: "center" });

    const rect = el.getBoundingClientRect();
    const scrollY = window.scrollY;

    return {
      found: true,
      x: Math.max(0, rect.left - pad),
      y: Math.max(0, rect.top + scrollY - pad),
      width:  rect.width  + pad * 2,
      height: rect.height + pad * 2,
    };
  }, phrase, panelWidth, padding);

  if (!result.found) {
    console.warn(`[excerpt] Phrase not found: "${phrase}" — falling back to full viewport screenshot`);
    fs.mkdirSync(path.dirname(path.resolve(outputPath)), { recursive: true });
    await page.screenshot({ path: outputPath, type: "png" });
    await browser.close();
    console.log(`[excerpt] → ${outputPath}`);
    return;
  }

  console.log(`[excerpt] Found paragraph at y=${Math.round(result.y)}, h=${Math.round(result.height)}`);

  // Screenshot the clipped region
  fs.mkdirSync(path.dirname(path.resolve(outputPath)), { recursive: true });
  await page.screenshot({
    path: outputPath,
    type: "png",
    clip: {
      x:      Math.round(result.x),
      y:      Math.round(result.y),
      width:  Math.min(Math.round(result.width),  viewportW),
      height: Math.round(result.height),
    },
  });

  await browser.close();
  console.log(`[excerpt] → ${outputPath}`);
})();
