# Changelog

## 3.1.0.1

Stability-hardening patch release.

- Pinned the AqualinkD source version for reproducible builds (`AQUALINKD_VERSION`, default `v3.1.0`; set to `latest` to track newest).
- Removed the build-time fetch of the start script from upstream `master` — the add-on now ships its own copy.
- Added a Docker `HEALTHCHECK` that verifies both the web UI and the serial bridge (`/aquadconf/tty.Pool`).
- Config is now regenerated from an immutable template, validated, and written atomically. A bad/partial options set aborts startup instead of writing a broken config, and the previous working config is preserved.
- Hardened the `socat` reconnect loop: stale PTY symlinks are cleared each iteration, a 60 s inactivity timeout recovers half-open EW-11 sessions, and startup waits for the serial link before launching the daemon.
- Force `use_panel_aux_labels=no` so the button labels managed via the add-on options always take effect (folds in a previously uncommitted on-device edit).
- Added `Solar Heat` (button 7) and two spare `NONE` buttons to the default button set.

## 3.1.0

- Initial v3.1.0 release: AqualinkD as a Home Assistant add-on with full configuration via the add-on options UI.
