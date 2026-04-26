# Job Tracker — Meine Bewerbungen

Ein eigenständiger, web-basierter Bewerbungs-Tracker mit Multi-User-Authentifizierung, gehostet über Supabase. Komplett unabhängig von anderen Projekten.

![Status](https://img.shields.io/badge/status-ready-22c55e) ![Stack](https://img.shields.io/badge/stack-Supabase%20%2B%20Vanilla%20JS-a855f7)

---

## ✨ Features

- 🔐 **Login mit E-Mail + Passwort** — Konten werden vom Admin angelegt
- 👤 **Profil-Widget** in der Navbar (Avatar, Benutzername, Rolle)
- 👥 **Admin-Bereich** — Benutzer anlegen, löschen, Rolle ändern, Passwort zurücksetzen
- 🔒 **Daten-Isolation per RLS** — jeder sieht nur seine eigenen Bewerbungen (Admin sieht alle)
- 📋 **CRUD** für Bewerbungen mit allem Drum & Dran (Firma, Plattform, Status, Gehalt, Notizen, Anforderungen, Ansprechpartner …)
- 🎤 **Interview-Tracking** — Termin + Notizen, mit "Nächstes Interview"-Widget oben rechts
- ⏱ **Verlauf / Timeline** pro Bewerbung
- 📎 **Dokumente** anhängen (CV, Anschreiben, sonstige) — gespeichert in Supabase Storage
- 🔍 Suche, Filter (Status / Plattform / Favoriten), Sortierung
- 👀 Liste & Kanban-Ansicht
- ⭐ Favoriten
- ⬇️ Export der eigenen Daten als JSON

---

## 🚀 Lokal starten

```bash
# Im Projekt-Ordner:
python -m http.server 8765
```

Dann im Browser: <http://localhost:8765/>

Oder einfach `index.html` doppelklicken (öffnet als `file://`-URL — funktioniert genauso).

---

## 🌐 Deployment (kostenlos)

Da es eine reine Static-Site ist, läuft sie überall:

- **GitHub Pages** — Repo-Settings → Pages → Source: `main` Branch → fertig.
- **Netlify / Vercel** — Repo verbinden, Drag & Drop, oder `netlify deploy`.
- **Cloudflare Pages** — Repo verbinden, kein Build-Command nötig.

Backend (Supabase) läuft im EU-Free-Tier.

---

## 🏗 Architektur

| Schicht | Technologie |
|---|---|
| Frontend | Vanilla JS + Tailwind CDN, Single-File `index.html` |
| Auth | Supabase Auth (E-Mail / Passwort) |
| DB | Supabase Postgres mit RLS (Tabellen: `jt_profiles`, `jt_bewerbungen`, `jt_files`, `jt_timeline`) |
| Files | Supabase Storage Bucket `jt-files` (privat, per-User-Ordner) |
| Admin-Aktionen | Supabase Edge Function `jt-admin` (service-role, JWT-verifiziert) |

Der erste angelegte Benutzer wird automatisch zum **Admin** (per DB-Trigger). Danach können nur Admins über den Admin-Bereich neue Konten anlegen.

---

## 🔧 Konfiguration

Die Supabase-URL und der **publishable** Anon-Key sind direkt in `index.html` hinterlegt (oben im `<script>`-Tag). Der Anon-Key ist explizit dafür gedacht, im Frontend zu stehen — RLS-Policies regeln den Zugriff.

```js
const SUPABASE_URL = 'https://wuiiyewinbewjdyxmcvw.supabase.co';
const SUPABASE_ANON_KEY = '...'; // public anon key
```

Wenn du eine eigene Supabase-Instanz nutzen möchtest:
1. Neues Supabase-Projekt erstellen.
2. SQL aus `supabase/migrations/0001_init.sql` in den SQL-Editor kopieren und ausführen.
3. Edge Function `jt-admin` aus `supabase/functions/jt-admin/index.ts` deployen.
4. URL + Anon-Key in `index.html` anpassen.

---

## 🔐 Sicherheitsmodell

- **Passwörter** werden von Supabase mit bcrypt gehasht.
- **RLS** sorgt dafür, dass jede Query nur die eigenen Zeilen liefert (`user_id = auth.uid()`), außer der Caller hat Admin-Rolle.
- **Storage**-Pfad: `<user_id>/<bewerbung_id>/<file>` — Policies erzwingen, dass nur Owner oder Admin lesen / löschen kann.
- **Admin-Aktionen** (Benutzer anlegen / löschen) laufen NICHT direkt vom Client, sondern über die Edge Function — der Service-Role-Key bleibt server-seitig.

---

## 📜 Lizenz

MIT — privat genutzt, für Bewerbungs-Verwaltung.
