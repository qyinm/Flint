# Flint v0 Compatibility Matrix

This matrix records manual evidence for v0 command-palette template insertion. Direct insertion and clipboard fallback are tracked separately because Accessibility insertion can vary by target app.

Status values:

- `works` — verified manually
- `broken` — tested and failed
- `unknown` — not yet tested
- `planned` — target selected for first dogfood pass

| Target app | Direct Accessibility insertion | Clipboard fallback | Status | Notes |
|---|---|---|---|---|
| ChatGPT web | unknown | planned | planned | Test with browser text field focused. |
| Claude web | unknown | planned | planned | Test with browser text field focused. |
| Cursor | unknown | planned | planned | Test editor and chat input separately if possible. |
| VS Code | unknown | unknown | backlog | Optional v0 target after first 3. |
| Terminal or iTerm2 | unknown | unknown | backlog | Direct insertion may be limited; fallback expected. |
| Generic browser text field | unknown | unknown | backlog | Use as control target. |

## First-pass manual protocol

1. Launch FlintApp.
2. Focus the target app input field.
3. Open Flint with the global hotkey or menu bar item.
4. Select a template.
5. Use **Insert or Copy**.
6. Record whether direct insertion worked.
7. If direct insertion fails or permission is denied, paste the copied prompt and record clipboard fallback status.

## Current evidence summary

- Automated renderer evidence exists via `swift test`.
- Manual target-app evidence is scaffolded but not completed in this headless agent run.
- v0 should remain dogfood-only until at least 3 target rows are manually verified.
