# Amanuensis Plugin

A [Discourse](https://www.discourse.org/) plugin for viewing Writers' Room meeting records from [Amanuensis](https://github.com/eklaassen/amanuensis).

## Features

- **Meetings list** — card-based view of all meetings with status badges and source indicators
- **Meeting detail** — metadata, AI summaries (Google Meet), vintage NotesBot transcripts, proposal items, applied change history
- **Group-based access** — restrict viewing to a designated Discourse group
- **NotesBot support** — foldable vintage transcript view with speaker-colored chat rendering

## Installation

Add the plugin to your Discourse `plugins/` directory:

```bash
cd /var/discourse/plugins
git clone https://github.com/eklaassen/amanuensis-plugin.git
cd /var/discourse
./launcher rebuild app
```

## Configuration

Configure via Discourse admin settings (`/admin/site_settings/category/plugins`):

| Setting | Description |
|---|---|
| `amanuensis enabled` | Enable the plugin |
| `amanuensis api url` | Amanuensis API base URL |
| `amanuensis api secret` | Bearer token for API auth |
| `amanuensis admin key` | Admin key for meeting ingestion |
| `amanuensis viewing group` | Discourse group allowed to view meetings |

## Development

Plugin structure:

```
app/controllers/amanuensis/   # Rails controllers
app/views/amanuensis/         # ERB templates
assets/stylesheets/           # SCSS stylesheets
config/settings.yml           # Plugin settings
plugin.rb                     # Entry point and routes
```

### Running tests locally

This repo has no Gemfile or `rails_helper.rb` of its own — a Discourse plugin
isn't a standalone app, it only runs loaded into a full copy of Discourse
core (see `spec/requests/amanuensis/uploads_api_controller_spec.rb`'s
`sign_in`, `Fabricate`, `SiteSetting` — none of those exist in this repo).
So running the RSpec suite, locally or in CI, means having an entire second
application around to boot it in.

`script/test-local` sets that up with Docker, using the same
`discourse/discourse_test:slim` image and setup steps as the `plugin-tests`
CI job (`.github/workflows/ci.yml` → `discourse/.github`'s reusable
`discourse-plugin.yml` workflow), so a local pass means the same thing a CI
pass does. It clones `discourse/discourse` core into
`~/projects/discourse-testenv/core` (override with `DISCOURSE_TESTENV_DIR`)
and live bind-mounts *this* working directory into the container at
`plugins/amanuensis` — edits here are visible inside the container
immediately, no rebuild or re-sync step.

```bash
script/test-local up      # first run: ~15-30 min, pulls the image, installs gems + JS deps, migrates a test DB
script/test-local test    # bin/rspec, everything except spec/system (see below)
script/test-local test plugins/amanuensis/spec/requests/amanuensis/uploads_api_controller_spec.rb
script/test-local down    # stop and remove the container
```

`up` is idempotent and safe to re-run: gems (`vendor/bundle`) and JS
deps (`node_modules`) live inside the mounted core checkout on disk, so they
survive `down`/`up` and only reinstall if missing. Only Postgres and Redis
live inside the container itself, so those (and the migrated schema) get
recreated — a few seconds — on every `up`.

Needs Docker running and roughly 3-4 GB of free disk for the image, core
checkout, gems, and JS deps combined.

#### System specs (`spec/system/**`)

These drive a real browser and need Chromium, which the plain container
above doesn't have — add `--browsers` to every subcommand to use
`discourse_test:slim-browsers` instead, in its own separate container
(`up --browsers` installs Chromium the first time; that install lives in
the container's own filesystem, not the mounted core checkout, so unlike
gems/JS deps it does *not* survive `down --browsers` + `up --browsers`):

```bash
script/test-local up --browsers
script/test-local test --browsers                                    # everything, including spec/system
script/test-local test --browsers plugins/amanuensis/spec/system/amanuensis_upload_spec.rb
script/test-local down --browsers
```

The plain (non-`--browsers`) `test` command explicitly excludes
`spec/system` from its default whole-suite run — that container has no
browser to run them in at all — matching CI's own `backend_tests`/
`system_tests` split in `discourse-plugin.yml`, which excludes it there for
the same reason.

## License

MIT
