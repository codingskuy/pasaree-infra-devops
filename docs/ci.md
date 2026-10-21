# CI Pasaree

Workflow: `.github/workflows/ci.yml` (PSR-OPS-002, QA-002).

| Job | Repo | Perintah |
|---|---|---|
| infra | repo ini | `docker compose config`, cek tautan, larangan rahasia |
| backend | pasaree-backend-service | `cargo test --locked`, `cargo clippy -D warnings`, lint `docs/api/openapi.yaml` (Redocly) |
| web | pasaree-web | `bun install --frozen-lockfile`, `bun run check`, `bun test` |
| app-kmp | pasaree-app-kmp | `./gradlew build` (Java 17) |
| python | pasaree-ai-models, pasaree-data-pipeline | `pip install -e .`, `pytest` |
| design | pasaree-design | `bun run validate:tokens` (nama skrip asumsi) |
| gerbang-qa | semua | gagal bila satu job gagal |

Pemicu: push ke `main`, PR, manual, dan harian 03:00 WIB.

Catatan operasional:
- Repo pasaree-* publik sehingga `actions/checkout` lintas-repo tanpa token. Bila ada yang jadi privat, tambah secret `CI_CHECKOUT_TOKEN` dan berikan ke `with.token`.
- Job akan merah bila repo target belum punya berkasnya (mis. `Cargo.lock`, `bun.lock`, `gradlew`, tes). Itu disengaja: gerbang tidak boleh hijau palsu.
- Jadikan `gerbang-qa` required check di proteksi `main` (usulan, perubahan proteksi dilakukan pemilik org).
- Tiap repo juga sebaiknya punya CI sendiri yang memanggil perintah di atas; workflow ini adalah gerbang rilis terpusat.
