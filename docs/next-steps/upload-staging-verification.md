# Verify the upload path against a real browser and real S3

**Scope:** verification, no code · **Depends on:** amanuensis#184/#191 and amanuensis-plugin#20/#25 — all merged · **Status:** never done

> Do this **before** building anything further on top of uploads. Three defects shipped through fully green CI on both sides; one real upload would have caught all three in about a minute.

## 1. Why CI wasn't enough

All three defects lived in the **seam between the two systems, where each side mocks the other**:

| Defect | Why every test passed |
|---|---|
| Plugin sent ADMIN_SECRET, API required PLUGIN_SECRET → 401 on every upload | The plugin's WebMock stub matches on URL and returns a canned body; it never validates the token. The API's tests used whichever secret the test itself supplied. |
| `Content-Type` mismatch → `SignatureDoesNotMatch` from S3 | Both sides mock S3 entirely. No test ever produced a signature. |
| No CSRF token reached the server | Rails disables forgery protection in the test env, and request specs never execute the page's JavaScript. |

Both sides can be internally consistent and mutually incompatible indefinitely. **More unit tests would not have found any of them.** Only running the real thing does.

## 2. Tier 1 — contract diff (free, no environment)

Cheapest and it already caught the credential mismatch. For each cross-repo call:

- every field the plugin sends vs. the TypeBox schema that receives it
- every field the plugin reads vs. what the route actually returns
- the credential each side uses

Worth repeating whenever either contract changes.

## 3. Tier 2 — curl against a live API (~1 minute, no Discourse)

Catches the credential and signature bugs without any browser:

```bash
curl -X POST "$API/v1/plugin/uploads" \
  -H "Authorization: Bearer $ADMIN_SECRET" \
  -H 'Content-Type: application/json' \
  -d '{"filename":"t.mp3","size_bytes":1024,"title":"T","recorded_at":"2026-08-01T19:00:00Z"}'
```

Then PUT with the **exact** `content_type` from that response:

```bash
curl -X PUT --upload-file t.mp3 -H "Content-Type: audio/mpeg" "$UPLOAD_URL"
```

Then complete, and confirm a Meeting row appears at `status='transcribing'`, `source='manual_upload'`.

⚠️ **`ADMIN_SECRET` is `Type.Optional` in config.** If it isn't set in the target environment these routes 401 unconditionally. The admin dashboard uses the same secret via `requireBasicAuth`, so it should already be set — confirm rather than assume.

## 4. Tier 3 — staging, as a real writer

The only thing that exercises the browser half.

1. **Access** — the Upload route is reachable for a writing-group member and 403s for everyone else
2. **Happy path** — upload a small `.mp3`; the progress bar moves; a Meeting appears at `transcribing`
3. **Large file** — ~1 GB. The only way to learn whether a **single PUT** survives a real network. There is no resume: a drop at 90% restarts from zero. If this fails in practice, that is the signal to build multipart.
4. **Navigation guard** — navigate away mid-upload, confirm the browser prompts
5. **Rejections** — a `.pdf` and an oversized file are both refused before any presign is minted
6. **Ownership** — as writer B, attempt to complete writer A's `upload_id`; expect 403

## 5. Still unverified even after all of the above

- Whether the transcription pipeline handles `source='manual_upload'` end to end
- Hetzner Object Storage's S3 compatibility beyond a single PUT (part-size minimums and ETag semantics differ, and would matter if multipart is ever added)

## 6. Acceptance criteria

- Tier 2 completes end to end against a real environment, producing a real Meeting row
- Tier 3 items 1, 2, 5, and 6 pass on staging
- Item 3 is attempted at least once, with the outcome recorded either way — a pass and a failure are both decision-grade information about multipart
