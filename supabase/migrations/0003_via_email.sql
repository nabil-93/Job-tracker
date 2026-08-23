-- ============================================================
-- Kennzeichnung: wurde die Bewerbung per E-Mail verschickt?
-- Dient als Filter in der Toolbar ("Per E-Mail").
-- ============================================================

alter table public.jt_bewerbungen
  add column if not exists via_email boolean not null default false;
