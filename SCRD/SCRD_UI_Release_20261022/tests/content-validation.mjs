import assert from 'node:assert/strict';
import fs from 'node:fs';
import { DatabaseSync } from 'node:sqlite';

const sql = fs.readFileSync(new URL('../d1_schema_migration.sql', import.meta.url), 'utf8');
const db = new DatabaseSync(':memory:');
try {
  db.exec(sql);
  const rows = db.prepare("SELECT slug, page_group, status, title_vi, title_en, content_vi, content_en FROM cms_pages WHERE slug IN ('tong-quan','trang-chu-noi-dung')").all();
  const bySlug = new Map(rows.map(row => [row.slug, row]));
  assert.ok(bySlug.has('tong-quan'), 'missing About page');
  assert.ok(bySlug.has('trang-chu-noi-dung'), 'missing homepage long-form content');
  assert.equal(bySlug.get('tong-quan').page_group, 'about');
  assert.equal(bySlug.get('trang-chu-noi-dung').page_group, 'home');
  for (const [slug, row] of bySlug) {
    assert.equal(row.status, 'published', `${slug} must be published`);
    for (const field of ['title_vi', 'title_en', 'content_vi', 'content_en']) {
      assert.ok(String(row[field] || '').trim().length > 0, `${slug}.${field} is empty`);
    }
    for (const field of ['content_vi', 'content_en']) {
      const plain = String(row[field]).replace(/<[^>]*>/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'");
      const words = plain.match(/[\p{L}\p{N}]+(?:[’'-][\p{L}\p{N}]+)*/gu) || [];
      assert.ok(words.length >= 4000, `${slug}.${field} has only ${words.length} tokens`);
      console.log(`PASS content ${slug}.${field}: ${words.length} words/tokens`);
    }
  }
  console.log('CONTENT VALIDATION: 4/4 minimum-length checks PASS');
} finally {
  db.close();
}
