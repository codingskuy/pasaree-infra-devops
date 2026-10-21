# Deploy per environment dan manajemen secret

Rujukan: PSR-OPS-003, `AGENTS.md`, `docs/auth.md`. Tidak ada rahasia nyata di repo; `.env.example` hanya berisi placeholder.

## Lingkungan

| Env | Cara jalan | Sumber konfigurasi | DB |
|---|---|---|---|
| lokal | `cp .env.example .env && docker compose up --build` | `.env` (diabaikan git) | Postgres 16 di Compose, DB `pasaree`, port host 5433 |
| staging | backend Rust + web, deploy lewat pipeline rilis | secret store env staging | DB `pasaree` staging, terpisah |
| prod | sama dengan staging | secret store env prod | DB `pasaree` prod, terpisah |

Port lokal: backend 8101 (`/kesehatan`), web 8102. DB `pasaree` tidak boleh dibagi dengan divisi lain, dan tiap environment memakai instansi DB sendiri.

Platform staging/prod (penyedia hosting, nama secret store) BELUM diputuskan di dokumen v1.0.0. Bagian ini mendefinisikan kontrak konfigurasinya saja; keputusan platform butuh ADR baru (ADR-0002).

## Daftar secret

| Nama | Dipakai oleh | Lokal | Staging/prod | Rotasi |
|---|---|---|---|---|
| `POSTGRES_PASSWORD` | db, `DATABASE_URL` | `.env` | secret store | 90 hari atau saat orang keluar |
| `DATABASE_URL` | backend | dirakit Compose | secret store | ikut password |
| `JWT_SECRET` (kunci JWT) | backend | `.env` | secret store, berbeda tiap env | 90 hari; rotasi mengakhiri sesi |
| `JWT_AUD` | backend | `pasaree` (bukan rahasia) | `pasaree` | tidak berubah |
| `LUMBUNG_SERVICE_KEY` | backend (proksi Lumbung) | kosong | secret store / secret CI | 90 hari, koordinasi divisi Lumbung |
| `PASAREE_API_BASE_URL` | web | `.env` | konfigurasi env | bukan rahasia |

Aturan:
- Dilarang commit `.env`, `*.pem`, `*.key`, keystore. `.gitignore` memblokir `.env` dan `.env.*` kecuali `*.example`; CI (job `infra`) gagal bila berkas rahasia terlacak.
- Kunci JWT dan password berbeda di tiap environment; jangan salin nilai prod ke lokal.
- rahasia yang pernah bocor ke git dianggap bocor, rotasi segera lalu catat di tiket.
- Secret kunci penandatanganan mobile (keystore Android, sertifikat iOS) hanya di secret CI/penyimpanan terenkripsi, tidak di repo.

## Rilis

| Platform | Jalur |
|---|---|
| Mobile Android | Play Store dan APK sideload |
| Mobile iOS | TestFlight |
| Web | browser saja (tidak ada paket desktop/MSIX) |

Urutan rilis: tandai versi, pastikan job `gerbang-qa` hijau, deploy ke staging, uji asap (`/kesehatan`, login, katalog), deploy prod, umumkan di TownHall. Rollback: deploy ulang versi sebelumnya; migrasi DB harus maju-kompatibel agar rollback aman.

## Dependensi terbuka

- `pasaree-backend-service` belum punya `Dockerfile`; `docker compose up --build` gagal pada layanan `backend` sampai ada.
- Nama variabel backend (`JWT_SECRET`, `LUMBUNG_SERVICE_KEY`) adalah asumsi dari AGENTS.md; sesuaikan bila kode backend memakai nama lain.
