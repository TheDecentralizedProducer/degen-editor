#!/usr/bin/env node
// article-highlight.js — screenshot a news article with a yellow marker highlight
// on specific text, sized for 9:16 vertical video (1080px wide).
//
// Usage:
//   node scripts/article-highlight.js <url> "<phrase to highlight>" <output.png>
//
// Example:
//   node scripts/article-highlight.js \
//     https://example.com/article \
//     "DeSantis signed the bill" \
//     projects/2026-07-14-clip/edit/background.png

const puppeteer = require(
  require.resolve("puppeteer-core", {
    paths: [__dirname + "/../tools/hyperframes/node_modules"],
  })
);
const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");

const [, , url, phrase, outputPath] = process.argv;

if (!url || !phrase || !outputPath) {
  console.error(
    "Usage: node scripts/article-highlight.js <url> \"<phrase>\" <output.png>"
  );
  process.exit(1);
}

// Find system Chrome
function findChrome() {
  const candidates = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium-browser",
    "/usr/bin/chromium",
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  // Try hyperframes' managed browser
  try {
    const p = execSync(
      "node tools/hyperframes/packages/cli/dist/cli.js browser --path 2>/dev/null",
      { cwd: path.dirname(__dirname), encoding: "utf8" }
    ).trim();
    if (p && fs.existsSync(p)) return p;
  } catch {}
  return null;
}

(async () => {
  const chromePath = findChrome();
  if (!chromePath) {
    console.error(
      "Chrome not found. Install Google Chrome or run: npx hyperframes browser install"
    );
    process.exit(1);
  }

  console.log(`[article-highlight] Chrome: ${chromePath}`);
  console.log(`[article-highlight] URL: ${url}`);
  console.log(`[article-highlight] Phrase: "${phrase}"`);

  const browser = await puppeteer.launch({
    executablePath: chromePath,
    headless: true,
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--window-size=1080,1920",
    ],
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1080, height: 1920, deviceScaleFactor: 2 });

  console.log("[article-highlight] Loading page…");
  await page.goto(url, { waitUntil: "networkidle2", timeout: 30000 });

  // Dismiss cookie banners / paywalls with a brief wait
  await new Promise((r) => setTimeout(r, 1500));

  // Inject yellow highlight on all matches of the phrase (case-insensitive)
  const found = await page.evaluate((searchPhrase) => {
    function escapeRegex(s) {
      return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
      null
    );

    const matches = [];
    let node;
    while ((node = walker.nextNode())) {
      const idx = node.nodeValue
        .toLowerCase()
        .indexOf(searchPhrase.toLowerCase());
      if (idx !== -1) matches.push(node);
    }

    if (matches.length === 0) return false;

    for (const textNode of matches) {
      const re = new RegExp(escapeRegex(searchPhrase), "gi");
      const html = textNode.nodeValue.replace(
        re,
        (m) =>
          `<mark style="background:#FFD700;color:inherit;padding:2px 0;border-radius:2px;-webkit-print-color-adjust:exact;">${m}</mark>`
      );
      const span = document.createElement("span");
      span.innerHTML = html;
      textNode.parentNode.replaceChild(span, textNode);
    }

    return true;
  }, phrase);

  if (!found) {
    console.warn(
      `[article-highlight] WARNING: phrase not found on page — "${phrase}"`
    );
    console.warn(
      "[article-highlight] Screenshot will still be taken without highlight."
    );
  } else {
    console.log("[article-highlight] Phrase highlighted.");
  }

  // Scroll the first highlight into view, center it vertically
  if (found) {
    await page.evaluate(() => {
      const mark = document.querySelector("mark");
      if (mark) {
        mark.scrollIntoView({ block: "center", inline: "nearest" });
      }
    });
    await new Promise((r) => setTimeout(r, 300));
  }

  // Screenshot the visible viewport (1080×1920)
  fs.mkdirSync(path.dirname(path.resolve(outputPath)), { recursive: true });
  await page.screenshot({ path: outputPath, type: "png" });

  await browser.close();

  console.log(`[article-highlight] Saved → ${outputPath}`);
})();
