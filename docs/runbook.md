# Runbook Infra Pasaree

Rujukan: PSR-OPS-004, ADR-0001 (butir 2 dan 7), BR-304 (BRD 30-keuangan-komisi). Pemantauan dan alarm: `docs/pemantauan.md`. Deploy dan secret: `docs/deploy.md`.

## 1. Jalan lokal penuh

`cp .env.example .env`, isi placeholder, lalu `docker compose up --build`. Backend `http://localhost:8101/kesehatan`, web `http://localhost:8102`.

## 2. Cadangan DB `pasaree`

| Item | Ketentuan |
|---|---|
| Frekuensi | harian, di luar jam ramai (usul 02:00 WIB) |
| Perintah | `scripts/backup-db.sh` (pg_dump format custom dari volume `pasaree-db`) |
| Retensi | 14 harian + 8 mingguan, simpan di penyimpanan terenkripsi terpisah dari host DB |
| Uji pulih | tiap pekan: `scripts/restore-test.sh` (pulih ke DB sementara `pasaree_restore_test`, lalu dihapus) |
| Bukti | catat tanggal, berkas, hasil `OK pulih ...` di tiket mingguan ops |

Pulih sungguhan (insiden): hentikan backend, `pg_restore` cadangan terbaru ke DB baru, periksa jumlah baris tabel transaksi dan escrow, ganti `DATABASE_URL`, nyalakan backend, jalankan rekonsiliasi (bagian 5) untuk jendela waktu yang hilang. Cadangan dilarang dipulihkan ke DB divisi lain.

Uji pulih yang gagal = insiden prioritas tinggi; cadangan dianggap tidak ada sampai berhasil diuji ulang.

## 3. 401 massal

1. Konfirmasi lingkup: `curl -i http://<host>:8101/kesehatan` (200 berarti backend hidup; masalah ada di token).
2. Periksa `JWT_AUD` di backend harus tepat `pasaree` (`docs/auth.md`). Token dari divisi lain (audiens berbeda) memang harus ditolak.
3. Periksa `JWT_SECRET` tidak berubah/tertukar antar-env; rotasi kunci mengakhiri semua sesi (login ulang).
4. Periksa jam server (selisih jam membuat token kedaluwarsa dini); TTL akses 15 menit, refresh 7 hari (standar AGENTS divisi).
5. Setelah perbaikan, redeploy backend, uji login dan satu panggilan terautentikasi, umumkan selesai.

Web tidak mendapat backend: periksa `PASAREE_API_BASE_URL` (lokal `http://localhost:8101`, di Compose `http://backend:8101`), cek `docker compose ps` dan log backend, lalu uji `/kesehatan` dari dalam kontainer web.

## 4. Rilis

Tandai versi, pastikan job `gerbang-qa` hijau, deploy staging, uji asap, deploy prod, umumkan di TownHall. Rollback: deploy ulang versi sebelumnya.

## 5. Tiket rekonsiliasi prioritas

Pemicu (ADR-0001 butir 7): rekonsiliasi harian Pasaree-Lumbung menemukan selisih lebih dari Rp1.000, atau status menggantung lebih dari 2x24 jam (escrow belum dilepas, payout T+1 hari kerja terlewat).

| Langkah | Penanggung | Batas waktu |
|---|---|---|
| Buat tiket prioritas tinggi (label `rekonsiliasi`, sertakan ID transaksi, selisih IDR, umur status) | DevOps on-call Pasaree | 1 jam kerja sejak terdeteksi |
| Akui dan tetapkan pemilik | Lead Backend Pasaree | 4 jam kerja |
| Telusuri: bandingkan ledger Pasaree dengan catatan kasir/payout Lumbung | Backend Pasaree + Keuangan Lumbung | 1 hari kerja |
| Koreksi lewat entri penyeimbang (bukan ubah/hapus entri lama), uang integer IDR, komisi `floor()` | Backend Pasaree, disetujui Keuangan | 2 hari kerja |
| Tutup tiket dengan akar masalah dan bukti saldo cocok | Pemilik tiket | segera setelah cocok |

Jika belum selesai dalam 2 hari kerja, eskalasi ke manajer divisi Pasaree dan Lumbung. Dilarang menyentuh DB atau kas divisi lain; koreksi sisi Lumbung dilakukan tim Lumbung.

CATATAN: nama peran dan batas waktu di atas adalah usulan operasional (dokumen v1.0.0 tidak menetapkan penanggung dan SLA respons); minta persetujuan lewat ADR sebelum dijadikan komitmen.
