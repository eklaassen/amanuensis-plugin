# Document ingestion — txt, md, json, pdf, docx

**Scope:** cross-repo · **Depends on:** audio upload path (shipped) · **Status:** not started

> The missing half of the upload feature. The original request was "a text file (txt, pdf, doc, md, and json supported with extreme validation) **or** any audio recording". Only audio shipped.

## 1. Why this can't reuse the audio path

`POST /v1/plugin/uploads/:id/complete` inserts a **Meeting** at `status='transcribing'`, `source='manual_upload'`, and enqueues the transcription pipeline. A PDF has no `recorded_at` and transcribing it is meaningless.

So this is not a widened allowlist on `CONTENT_TYPE_BY_EXTENSION`. It needs its own destination, and that is a **product question before it is an engineering one**:

- What *is* an uploaded document, in the model? Source material attached to an existing meeting? A standalone artifact? Something that feeds canon/proposals directly?
- What should happen to it — text extraction and storage, summarization, indexing for retrieval, nothing until asked?
- Where does it surface in the plugin?

**Answer that first.** The transport half is easy and largely already built; the destination is what's undefined.

## 2. What can be reused as-is

- Presigned direct-to-storage, with the server choosing the key and pinning `Content-Type` into the signature.
- The plugin's ownership claim in Redis, `UPLOAD_ID_FORMAT`, filename sanitization, and rate limits (`lib/amanuensis/upload_policy.rb`, `app/controllers/amanuensis/uploads_api_controller.rb`).
- The Ember upload route, with a second form mode.

`UploadPolicy::ALLOWED_EXTENSIONS` and the API's `CONTENT_TYPE_BY_EXTENSION` would each gain a document tier — deliberately a **separate** list, so a document extension can never route into the transcription path.

## 3. Validation — what it can and cannot do

Stated plainly because "extreme validation" is easy to over-promise:

**With presigned direct upload the plugin never sees a byte.** Nothing in either the plugin or the API can inspect content. Every check on the request path is metadata only. Real content validation belongs in whatever sandboxed worker parses the file.

Per-format risk, all worker-side:

- **PDF** — `/OpenAction`, `/AA`, `/JavaScript`, `/Launch`, `/EmbeddedFile` auto-actions; malformed xref loops; Flate compression bombs. Parse in a sandbox with rlimits, strip action dictionaries, never hand the raw file to a browser.
- **DOCX is a zip of XML**, which is four problems: **XXE** (disable external entities and DTD loading unconditionally), **zip bombs** (cap uncompressed total, compression ratio, entry count), **zip-slip** (read entries in memory, never extract to disk), and **macros** — a `.docx` can still contain `word/vbaProject.bin`. Inspect the OPC package; the extension does not tell you the format.
- **JSON** — deep-nesting stack exhaustion, huge-array memory blowup. Streaming parser, depth cap ~64, byte cap enforced *before* parse.
- **txt/md** — benign as bytes. The risk is entirely at render time.

**`.doc` (legacy binary) stays off the list.** Decided earlier and still right: OLE2/CFB is a filesystem-in-a-file with decades of parser CVEs, and the `soffice --headless` conversion path is a large C++ surface with its own macro engine. If it is genuinely needed later, the answer is a hard-sandboxed converter with no network and a hard timeout, not a library call.

**Magic-byte sniffing must happen worker-side**, comparing leading bytes against the claimed extension.

## 4. Stored XSS

Extracted text is fully attacker-controlled and will render somewhere. It must go through `Amanuensis::Sanitizer` — the same allowlist already used for meeting summaries. No `html_safe` / `raw` / `htmlSafe` on anything upload-derived. Filenames are attacker-controlled too.

## 5. Prompt injection — say it plainly

**File validation cannot prevent prompt injection.** A well-formed, virus-free, correctly-typed `.txt` containing "ignore previous instructions and…" is indistinguishable from legitimate content at the file level. There is no scanner for this.

The mitigations are architectural and belong in the pipeline: keep extracted text in a clearly-delimited data channel, never as instructions; give the ingestion model no privileged tools; and keep a human between model output and anything that writes to Discourse. Worth stating in the README so the next person doesn't assume the extension allowlist covers it.

## 6. Acceptance criteria

- A writer can upload each supported document type and see it land wherever §1 decides it lands.
- A document extension cannot reach the transcription enqueue path — assert this directly.
- An oversized or wrong-typed file is refused before a presign is minted.
- Extracted text renders through `Amanuensis::Sanitizer`.
- Worker-side parsing runs sandboxed with explicit memory, CPU, and wall-clock limits.

## 7. Not in scope

- `.doc`, `.docm`, `.rtf`, `.xls`, `.ppt`, and every archive format.
