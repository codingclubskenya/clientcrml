-- Add the profile fields previously stored in Supabase Auth metadata.
ALTER TABLE users
  ADD COLUMN id_number VARCHAR(100) NULL,
  ADD COLUMN avatar_url TEXT NULL;
