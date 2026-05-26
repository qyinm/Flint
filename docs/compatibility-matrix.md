# Flint v0 Compatibility Matrix

This matrix records manual evidence for v0 command-palette copy/paste behavior.
The command palette is copy-only: it copies the expanded prompt to the clipboard,
then the user pastes into the active target app. Typed trigger replacement is a
separate Accessibility-powered path and is not part of this v0 palette matrix.

Status values:

- `works` — verified manually
- `broken` — tested and failed
- `unknown` — not yet tested
- `planned` — target selected for first dogfood pass

| Target app | Clipboard copy | Paste into target | Status | Notes |
|---|---|---|---|---|
| ChatGPT web | planned | planned | planned | Test with browser text field focused. |
| Claude web | planned | planned | planned | Test with browser text field focused. |
| Cursor | planned | planned | planned | Test editor and chat input separately if possible. |
| VS Code | unknown | unknown | backlog | Optional v0 target after first 3. |
| Terminal or iTerm2 | unknown | unknown | backlog | Paste behavior may vary by shell/editor mode. |
| Generic browser text field | unknown | unknown | backlog | Use as control target. |

## First-pass manual protocol

1. Launch FlintApp.
2. Focus the target app input field.
3. Open Flint with the global hotkey or menu bar item.
4. Select a template.
5. Use **Copy**.
6. Paste into the focused target app.
7. Record whether the copied prompt matched the selected template and whether paste worked in the target field.

## Current evidence summary

- Automated renderer evidence exists via `swift test`.
- Manual target-app evidence is scaffolded but not completed in this headless agent run.
- v0 should remain dogfood-only until at least 3 target rows are manually verified.
