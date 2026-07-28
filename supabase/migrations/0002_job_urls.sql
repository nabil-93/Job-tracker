-- ============================================================
-- Mehrere Links pro Bewerbung.
-- job_url (text) bleibt bestehen = der erste/primäre Link.
-- job_urls (jsonb) hält die vollständige Liste: [{label, url}, …]
-- ============================================================

alter table public.jt_bewerbungen
  add column if not exists job_urls jsonb not null default '[]'::jsonb;

-- Bestehende Einträge übernehmen: vorhandene job_url als ersten Link.
update public.jt_bewerbungen
   set job_urls = jsonb_build_array(jsonb_build_object('label', '', 'url', job_url))
 where job_urls = '[]'::jsonb
   and coalesce(job_url, '') <> '';
