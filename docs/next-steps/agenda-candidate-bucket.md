# Agenda candidate bucket — flag, collect, publish

**Scope:** cross-repo (`amanuensis` + `amanuensis-plugin`) · **Depends on:** plugin foundations (`Amanuensis::Permissions`, `ApiClient`, `ApiController`) — shipped · **Status:** not started, no code in either repo

> This is the **first** of the two features originally requested, and the larger one. Nothing exists yet: `git grep -i agenda` across both repos returns only unrelated comments.

## 1. Objective

Writers flag any forum topic as worth discussing. Flags accumulate in a bucket owned by the Amanuensis API. Separately, an admin draws from that bucket in a builder form and publishes a consistently-formatted agenda topic into the Writers' Room.

The key structural decision, already made: **flagging is decoupled from publishing.** This removes any concurrent-post-editing problem and makes the agenda structured data rendered through a template, rather than markdown scraped and re-parsed.

Ownership is **hybrid** — the API stores agenda items as structured data; the plugin reads them back and creates the Discourse topic.

## 2. API contract (build first — the plugin is blocked on it)

Bearer auth. The bucket is a read-tier operation (`pluginSecret`); publishing writes, so weigh `adminSecret` there, consistent with what `/v1/plugin/uploads` settled on.

- `POST /v1/plugin/agenda-candidates` — idempotent upsert keyed on `discourse_topic_id`. Body `{discourse_topic_id, title, url, note, flagged_by_user_id, flagged_by_username}`. Re-flagging a pending item updates the note → 200. Re-flagging a consumed item → 409 `already_consumed` with the owning `agenda_id`.
- `DELETE /v1/plugin/agenda-candidates/by-topic/:discourse_topic_id` → 204, or 409 if consumed.
- `GET /v1/plugin/agenda-candidates?status=pending&limit=100`
- `POST /v1/plugin/agendas` — create a draft from selected items + free-text sections. Must honour `Idempotency-Key`: a replay returns the **same** `agenda.id`, 200 not 201. Rejects any already-consumed item → 409 listing the offenders.
- `GET /v1/plugin/agendas/:id` — the read the plugin does inside the publish mutex.
- `POST /v1/plugin/agendas/:id/publish` — body `{discourse_topic_id}`, marks referenced items consumed. **Idempotent**: same topic id → 200; a *different* one → 409 `already_published` carrying the original. That 409 is what makes the plugin's retry job safe.

Follow the existing house style in `src/routes/v1/plugin/` — TypeBox schemas, `AppError.validationFailed` with `{pointer, rule, message}` (note it maps to **400**, not 422), injectable `opts.db`.

## 3. Plugin surfaces

**3a. Topic footer button.** `api.registerTopicFooterButton` in an `api-initializers/` file. Now much cheaper than when this was first planned — the plugin has a real Ember tree since #24/#26.

- Expose eligibility via `add_to_serializer(:current_user, :can_flag_agenda_candidate) { Amanuensis::Permissions.writer?(object) }`.
- Cache flagged-state in a topic custom field so the button renders without an upstream call per topic view: `register_topic_custom_field_type("amanuensis_agenda_state", :json)` plus `add_preloaded_topic_list_custom_field`. Treat it strictly as a **cache** — upstream wins; drift is cosmetic.
- Expose it on `topic_view` with `include_condition: -> { Amanuensis::Permissions.writer?(scope.current_user) }` so non-writers never see what's been flagged.
- A small `DModal` captures an optional note ("why this matters") — much more useful to the builder than a bare topic reference.

**3b/3c. Builder + publish.** An Ember route (staff only), reading the bucket and posting a selection back. On publish, inside `DistributedMutex.synchronize("amanuensis_agenda_publish_#{agenda_id}", validity: 60)`:

1. `GET /v1/plugin/agendas/:id` — if `discourse_topic_id` is already set, return it and stop
2. `PostCreator` — create the topic
3. write `topic.custom_fields["amanuensis_agenda_id"]`
4. `POST .../publish` — on failure, enqueue a retry job

Step 1 inside the mutex is what makes double-publish safe across app servers. Step 4 failing leaves a real topic and an unconsumed bucket, which a retry job fixes idempotently. The reverse ordering risks consuming the bucket with no topic to show for it — the worse failure.

## 4. Details that bite

- **`guardian.ensure_can_see!(topic)` on flag.** A writer must not be able to flag a topic they cannot read — the title and note end up on a published agenda. Easy to omit, and a real leak.
- **`PostCreator`**: use `create` + explicit `creator.errors` check, not `create!`, so title/duplicate errors return a structured 422 rather than a 500. Never `skip_validations: true`. `category` takes an id; guard a blank category setting up front or it fails opaquely. Tags apply only if `guardian.can_tag?` — otherwise silently dropped, so assert it in a spec.
- **`RateLimiter`** on the flag endpoint (~20/hr).
- **Filter the bucket server-side** for topics that no longer resolve or the admin can't see — not client-side.
- Predictable formatting was an explicit requirement, so pin the rendered template with a spec asserting exact output for a fixture agenda. Include an HTML comment marker (`<!-- amanuensis:agenda:{id} -->`) so future tooling can find these topics.

## 5. Acceptance criteria

- A writer sees the button on any topic they can read; a non-writer never sees it and a direct POST 403s.
- Flagging twice creates one bucket item; the button reflects state without a page reload.
- An admin can select, reorder, annotate, and publish; exactly one topic appears in the configured category with the items marked consumed.
- Double-submitting publish yields exactly one topic.
- Suite green in both repos.

## 6. Not in scope

- Auto-publishing an agenda from pipeline output. The human-in-the-loop review step is a deliberate mitigation against prompt injection reaching Discourse — preserve it.
