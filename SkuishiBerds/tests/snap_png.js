// Renders every .html snapshot in a folder to a .png next to it.
//   node tests/snap_png.js build/snapshots [scale]
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

(async () => {
	const dir = process.argv[2] || "build/snapshots";
	const scale = Number(process.argv[3] || 1);
	const browser = await chromium.launch();
	const files = fs.readdirSync(dir).filter((f) => f.endsWith(".html")).sort();
	for (const f of files) {
		const html = fs.readFileSync(path.join(dir, f), "utf8");
		const m = html.match(/#vp\{[^}]*width:(\d+)px;height:(\d+)px/);
		const width = m ? Number(m[1]) : 390;
		const height = m ? Number(m[2]) : 844;
		const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: scale });
		await page.setContent(html, { waitUntil: "load", timeout: 5000 }).catch(() => {});
		await page.screenshot({ path: path.join(dir, f.replace(/\.html$/, ".png")) });
		await page.close();
	}
	await browser.close();
	console.log(`${files.length} screenshots in ${dir}`);
})();
