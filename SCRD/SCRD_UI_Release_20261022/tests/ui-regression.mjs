import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const html = read('public/index.html');
const app = read('public/app.js');
const css = read('public/styles.css');
const examCss = read('EXAM/public/styles.css');
const migration = read('d1_schema_migration.sql');
const logo = 'public/assets/sky-first-logo-trimmed.webp';

const tests = [
  ['public shell includes a mobile navigation control connected accessibly to the menu', () => {
    assert.match(html, /id="mobileNavToggle"/);
    assert.match(html, /aria-controls="publicMainNav"/);
    assert.match(app, /classList\.toggle\('is-open'\)/);
    assert.match(app, /aria-expanded/);
  }],
  ['public menu contains all required route seeds', () => {
    for (const url of ['/', '/gioi-thieu', '/nghien-cuu-khoa-hoc', '/du-an-cong-dong', '/khao-thi-danh-gia', '/cong-bo-tai-lieu', '/hop-tac-doi-tac', '/tin-tuc-hoat-dong']) {
      assert.ok(migration.includes(`'${url}'`), `Missing required public route ${url}`);
    }
  }],
  ['mobile layout rules reflow navigation, forms, grids and footer', () => {
    assert.match(css, /@media\s*\(max-width:\s*760px\)/);
    assert.match(css, /\.main-nav\.is-open\s*\{\s*display:\s*flex/);
    assert.match(css, /\.grid-2,\s*\.grid-3,\s*\.grid-4\s*\{\s*grid-template-columns:\s*minmax\(0,1fr\)/);
    assert.match(css, /\.footer-grid\s*\{\s*grid-template-columns:\s*minmax\(0,1fr\)/);
  }],
  ['desktop/tablet layouts use fluid grid tracks instead of fixed 360px cards', () => {
    assert.match(css, /\.grid-2\s*\{\s*grid-template-columns:\s*repeat\(2,\s*minmax\(0,\s*1fr\)\)/);
    assert.match(css, /\.grid-3\s*\{\s*grid-template-columns:\s*repeat\(3,\s*minmax\(0,\s*1fr\)\)/);
  }],
  ['navigation links reject javascript/data protocols before rendering', () => {
    assert.match(app, /function getSafeMenuTarget/);
    assert.match(app, /parsed\.protocol === 'https:'/);
    assert.match(app, /parsed\.protocol === 'mailto:'/);
    assert.match(app, /return null;/);
  }],
  ['network errors use branded retry state and do not print backend error details in public UI', () => {
    assert.match(app, /page-state-spinner/);
    assert.match(app, /Retry connection/);
    assert.match(app, /support@skyfirst\.io\.vn/);
    assert.doesNotMatch(app, /<strong>\$\{isVi \? 'Chi tiết:' : 'Details:'\}<\/strong>/);
  }],
  ['Vietnamese and English controls and official support address remain present', () => {
    assert.match(html, /id="btnLangVi"/);
    assert.match(html, /id="btnLangEn"/);
    assert.match(html, /support@skyfirst\.io\.vn/);
    assert.match(app, /localStorage\.setItem\('skyfirst_lang'/);
  }],
  ['official logo asset exists and no generated hero image is required', () => {
    assert.ok(fs.existsSync(path.join(root, logo)));
    assert.match(html, /sky-first-logo-trimmed\.webp/);
    assert.match(css, /\.hero-visual img/);
  }],
  ['Exam portal has responsive UI refinements and reduced-motion support', () => {
    assert.match(examCss, /@media\(max-width:500px\)/);
    assert.match(examCss, /prefers-reduced-motion/);
    assert.match(examCss, /focus-visible/);
  }]
];

let passed = 0;
for (const [name, run] of tests) {
  run();
  passed++;
  console.log(`PASS UI ${passed}: ${name}`);
}
console.log(`UI REGRESSION: ${passed}/${tests.length} PASS`);
