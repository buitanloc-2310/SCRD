-- Require administrator-issued temporary passwords to be changed on first sign-in.
-- Apply after 0004_public_hero_copy_update.sql; backup and test in staging first.
ALTER TABLE users ADD COLUMN must_change_password INTEGER NOT NULL DEFAULT 0 CHECK (must_change_password IN (0, 1));
