# Harden `Amanuensis::ApiClient` against SSRF

**Scope:** `amanuensis-plugin` only · **Depends on:** nothing · **Status:** outstanding from the original foundations plan · **Size:** small

> Carried over from the Phase 1 plan and never done. Low severity on its own; more attractive now that `ApiClient.admin` carries upload traffic and mints write credentials.

## 1. Objective

`lib/amanuensis/api_client.rb` builds every request as `URI.join(SiteSetting.amanuensis_api_url, path)` and sends a bearer token to whatever host that resolves to. The base URL is admin-set, so this is not a user-facing hole — but it means **a compromised admin session can point the plugin at an internal address and have it issue authenticated requests**, with the admin key attached, and read the response body back through the meetings views.

That is a confused-deputy shape worth closing cheaply.

## 2. Changes

- **Require `https`** for the base URL (allow `http` only for `localhost` in development, if the dev workflow needs it).
- **Run the resolved host through `FinalDestination::SSRFDetector`** at request time, which is what Discourse core uses for exactly this and handles the cases a naive check misses: link-local (`169.254.0.0/16`), loopback, RFC1918, IPv6 equivalents, and DNS rebinding between check and connect.
- **Add a site-setting validator** so a bad `amanuensis_api_url` is rejected in the admin UI rather than failing per-request.
- **Scrub credentials from logs** — bearer tokens and presigned URLs. A presigned URL's query string *is* the credential; it must never reach a log line, an error message, or an exception payload.

## 3. Where it goes

All of it inside `ApiClient#request`, before the `Net::HTTP` call. Keep the existing narrow rescue list — do not widen to `StandardError`; a bug in the client should raise, not be reported as an upstream failure.

## 4. Acceptance criteria

- A base URL resolving to a private, loopback, or link-local address is refused, and no request is made
- A non-`https` base URL is refused outside development
- `amanuensis_api_url` cannot be saved to an invalid value in the admin UI
- No bearer token or presigned URL appears in any log output — assert this in a spec, since it is the kind of thing that regresses silently
- `spec/lib/amanuensis/api_client_spec.rb` covers the refusals; existing tests still pass

## 5. Not in scope

- Egress restrictions at the network layer. Worth having, but that is infrastructure, not this file.
