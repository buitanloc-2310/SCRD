import assert from 'node:assert/strict';
import fs from 'node:fs';
import { DatabaseSync } from 'node:sqlite';

const migrationDir = new URL('../migrations/', import.meta.url);
const readMigration = name => fs.readFileSync(new URL(name, migrationDir), 'utf8');
const db = new DatabaseSync(':memory:');
const migrations = [
  '0001_initial_schema.sql',
  '0002_cleanup_unverified_content.sql',
  '0003_home_about_longform.sql',
  '0004_public_hero_copy_update.sql',
  '0005_temporary_password_guard.sql',
  '0006_hero_description_split.sql'
];
try {
  db.exec(readMigration(migrations[0]));
  assert.ok(db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='users'").get(), 'initial schema must create users');
  db.exec(readMigration(migrations[1]));
  db.exec(readMigration(migrations[2]));

  // Known legacy hero defaults must be normalized by 0004.
  db.exec(readMigration(migrations[3]));
  const titleVi = db.prepare("SELECT config_value FROM system_config WHERE config_key='hero_title_vi'").get()?.config_value;
  const titleEn = db.prepare("SELECT config_value FROM system_config WHERE config_key='hero_title_en'").get()?.config_value;
  assert.equal(titleVi, 'NGHIÊN CỨU KHOA HỌC & PHÁT TRIỂN CỘNG ĐỒNG');
  assert.equal(titleEn, 'SCIENTIFIC RESEARCH & COMMUNITY DEVELOPMENT');

  // Migration 0004 must not overwrite a custom title, demonstrating non-destructive updates.
  db.prepare("UPDATE system_config SET config_value=? WHERE config_key='hero_title_vi'").run('Custom approved title');
  db.exec(readMigration(migrations[3]));
  assert.equal(db.prepare("SELECT config_value FROM system_config WHERE config_key='hero_title_vi'").get().config_value, 'Custom approved title');

  db.exec(readMigration(migrations[4]));
  const columns = db.prepare('PRAGMA table_info(users)').all().map(c => c.name);
  assert.ok(columns.includes('must_change_password'), 'upgrade migration must add the temporary-password guard');
  assert.equal(db.prepare("SELECT dflt_value FROM pragma_table_info('users') WHERE name='must_change_password'").get()?.dflt_value, '0');
  db.prepare("INSERT INTO users (id,email,full_name,password_hash,role,status) VALUES ('migration-user','migration@example.test','Migration User','x','member','active')").run();
  assert.equal(db.prepare("SELECT must_change_password FROM users WHERE id='migration-user'").get().must_change_password, 0, 'existing/new rows default to no forced change');

  // Migration 0006 separates the hero subtitle and supporting description without overwriting custom content.
  const unpack = value => {
    if (typeof value !== 'string') return value;
    try { const parsed = JSON.parse(value); return typeof parsed === 'string' ? parsed : value; } catch { return value; }
  };
  db.exec(readMigration(migrations[5]));
  const subtitleVi = unpack(db.prepare("SELECT config_value FROM system_config WHERE config_key='hero_subtitle_vi'").get()?.config_value);
  const subtitleEn = unpack(db.prepare("SELECT config_value FROM system_config WHERE config_key='hero_subtitle_en'").get()?.config_value);
  const descriptionVi = unpack(db.prepare("SELECT config_value FROM system_config WHERE config_key='hero_description_vi'").get()?.config_value);
  const descriptionEn = unpack(db.prepare("SELECT config_value FROM system_config WHERE config_key='hero_description_en'").get()?.config_value);
  assert.equal(subtitleVi, 'Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững.');
  assert.equal(subtitleEn, 'Connecting academic knowledge, standardized assessment, and sustainable community initiatives.');
  assert.equal(descriptionVi, 'Nền tảng chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.');
  assert.equal(descriptionEn, 'The official platform of Sky First Center for Research and Development.');
  db.prepare("UPDATE system_config SET config_value=? WHERE config_key='hero_subtitle_vi'").run(JSON.stringify('Phụ đề CMS do quản trị viên tự viết'));
  db.exec(readMigration(migrations[5]));
  assert.equal(unpack(db.prepare("SELECT config_value FROM system_config WHERE config_key='hero_subtitle_vi'").get().config_value), 'Phụ đề CMS do quản trị viên tự viết', 're-running migration must preserve a custom subtitle');
  console.log(`MIGRATION CHAIN: ${migrations.length}/${migrations.length} sequential SQL migrations PASS`);
  console.log('PASS: hero copy split into subtitle/description, CMS-authored content preserved, temporary-password guard defaults safely');
} finally {
  db.close();
}
