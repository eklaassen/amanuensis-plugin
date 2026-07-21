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

## License

MIT
