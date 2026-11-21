-- Lets signed-in users reach saved_movies through the API.
-- Projects that do not expose new tables automatically give the API roles no
-- privileges, so every request fails with "permission denied" before RLS runs.
-- RLS still limits every row to its owner. anon gets nothing.
-- The app only reads, adds and removes rows: upsert with ignoreDuplicates
-- is an insert that skips existing rows, so update is not needed.

grant select, insert, delete on table public.saved_movies to authenticated;
