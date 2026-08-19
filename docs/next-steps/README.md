# Next steps

Four pieces of work left after the upload feature shipped. Written up as separate specs so each can be picked up independently.

| Doc | Scope | Status |
|---|---|---|
| [Agenda candidate bucket](agenda-candidate-bucket.md) | cross-repo | Not started — blocked on API endpoints |
| [Document ingestion](document-ingestion.md) | cross-repo | Not started — needs a product decision first |
| [Upload staging verification](upload-staging-verification.md) | verification, no code | Never done |
| [ApiClient SSRF hardening](api-client-ssrf-hardening.md) | plugin only | Outstanding from the foundations plan |

## Suggested order

**Verification first.** Three defects reached `develop` through fully green CI on both repos, and a single real upload would have caught all of them. Building on top of an unverified upload path repeats the pattern.

**Then the agenda bucket**, as it is the larger of the two remaining features and was the one originally requested first. Its plugin half is much cheaper now that the plugin has real Ember routes.

**Document ingestion needs a product answer before engineering** — an uploaded PDF has no meeting to attach to and nothing to transcribe, so where it lands is undefined.

**SSRF hardening is small and independent**, and can slot in whenever.
