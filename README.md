# Flint

<p align="center">
  <strong>AI prompt templates from anywhere on macOS.</strong>
</p>

<p align="center">
  <a href="https://github.com/qyinm/Flint"><img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-black"></a>
  <a href="https://www.swift.org"><img alt="Swift" src="https://img.shields.io/badge/Swift-6.0-orange"></a>
  <img alt="Status" src="https://img.shields.io/badge/status-dogfood%20prototype-blue">
  <img alt="License" src="https://img.shields.io/badge/license-TBD-lightgrey">
</p>

Flint is a native macOS input layer for reusable AI prompt workflows. Type a short trigger like `:debug` or open a command palette, and Flint expands it into the right local prompt template for ChatGPT, Claude, Codex, Cursor, or any text field.

Flint is not another chatbot. It sits before the chatbot so prompt-heavy builders can stop copy-pasting the same review, debug, planning, and Codex task prompts.

Flint is inspired by tools like [espanso](https://espanso.org/) and [Wispr Flow](https://wisprflow.ai/): espanso proves how powerful typed text expansion can be, while Wispr Flow points toward a faster voice-first input layer. Flint applies that spirit specifically to reusable AI prompt templates.

## What works today

- Native macOS menu bar app
- Global hotkey command palette: `⌘⇧Space`
- Local YAML prompt templates
- Espanso-style typed triggers such as `:debug`, `:review`, `:plan`, `:codex`, and `:critic`
- Clipboard-first expansion with paste fallback
- Swift-tested template renderer

## Quick start

```bash
git clone git@github.com:qyinm/Flint.git
cd Flint
swift run FlintApp
```

Then type one of the built-in triggers in any text field:

| Trigger | Template |
| --- | --- |
| `:debug` | Bug Debugger |
| `:review` | Code Review |
| `:plan` | Implementation Plan |
| `:codex` | Codex Task |
| `:critic` | PRD Critic |

You can also click the menu bar item named `Flint` or press `⌘⇧Space` to open the command palette.

## macOS permissions

Typed trigger expansion uses a global keyboard event tap and simulated paste. macOS may require permission for the terminal or app process used to launch Flint.

Open:

```text
System Settings → Privacy & Security → Accessibility
```

Enable the terminal app you used to run `swift run FlintApp` (`Terminal`, `iTerm`, etc.). If trigger expansion is unavailable, the menu bar command palette and copy flow still work.

## Development

```bash
swift build
swift test
```

Current automated coverage focuses on template loading, trigger parsing, variable defaults, target-specific rendering, and placeholder replacement.

## Why Flint

AI-heavy developers repeatedly copy, paste, and edit the same prompt patterns:

- code review prompts
- debugging prompts
- planning prompts
- Codex/Hermes task prompts
- Seed-style specifications
- Korean/English rewrite prompts
- acceptance-criteria prompts

Existing tools solve pieces of the workflow:

- espanso expands typed snippets
- Wispr Flow handles voice dictation
- Raycast launches commands and snippets

But none of them feel like an AI-native prompt input layer shared across keyboard and voice.

Flint's wedge:

> AI prompt templates from keyboard or voice.

## Product Vision

Flint should eventually feel like:

> The input layer for AI work.

The user should stop thinking about where prompt templates live. They should invoke intent:

- type `:review` and get a code review prompt
- type `:seed` and get a structured Seed-style spec template
- say “review template” and insert the same template
- say “make this a Codex task” and transform the current idea
- reuse one prompt library across typed and spoken input

## Target User

Primary user:

- AI-tool-heavy developers
- people who use ChatGPT, Claude, Codex, Hermes, Cursor, Claude Code, or similar tools
- people who already reuse prompts manually
- people who may already use espanso, Raycast, Wispr Flow, TextExpander, or snippets

First user: the builder.

## MVP Wedge

The first useful version should prove one thing:

> Invoking AI prompt templates from anywhere feels faster and better than copy-paste or writing espanso YAML snippets.

### v0 — Command Palette + Template Insertion

Goal: prove reusable AI prompt templates are useful from anywhere.

Scope:

1. macOS menu bar app
2. Global hotkey opens command palette
3. Local template library with 3–5 real AI prompts
4. User selects a template
5. App inserts expanded text into the active app via Accessibility API or clipboard fallback

The dogfood path should also support espanso-style typed triggers such as
`:debug`, `:review`, `:plan`, `:codex`, and `:critic`. When Flint is running
with Accessibility permission, typing a trigger in any text field should replace
the trigger with the rendered local template.

Out of scope:

- voice trigger invocation
- AI transformations
- marketplace
- sync
- typed trigger customization UI

### v0.1 — Typed Trigger Expansion

Goal: compete with the most useful slice of espanso for AI prompts.

Scope:

1. typed triggers like `:review`, `:debug`, `:seed`, `:plan`
2. same template library as v0
3. basic variables and defaults
4. compatibility checks across browser, Cursor, VS Code, and terminal-like inputs

### v0.2 — Voice Trigger Invocation

Goal: prove the Wispr Flow-adjacent part without building full dictation.

Scope:

1. short voice commands only
2. examples: “review template”, “debug prompt”, “make Codex task”
3. Apple Speech first; local Whisper later if needed
4. voice invokes templates; it does not attempt continuous dictation yet

### v1 — Prompt Transformations

Goal: make Flint feel AI-native, not just like a snippet tool.

Examples:

- “make this Codex-ready”
- “add acceptance criteria”
- “turn this into Korean”
- “make it debugging-focused”

## Core Concepts

### Template

A reusable prompt body with optional variables.

Example:

```text
You are reviewing this code change.
Focus on: {{focus}}
Return:
1. Critical bugs
2. Edge cases
3. Test gaps
4. Smallest safe fix
```

### Trigger

A short typed or spoken phrase that invokes a template.

Examples:

- typed: `:review`
- spoken: “review template”
- spoken command: “make this a review prompt”

### Target

The destination format or tool style.

Examples:

- ChatGPT
- Claude
- Codex
- Hermes
- Cursor
- Generic Markdown

### Transformation

A lightweight AI or rule-based operation that changes a prompt.

Examples:

- make it shorter
- convert to Codex task
- add acceptance criteria
- turn this into Korean
- make it debugging-focused

## Technical Direction

Likely stack:

- Swift / SwiftUI for the native macOS shell
- menu bar app first
- Accessibility API for direct text insertion
- clipboard fallback when direct insertion fails
- Event taps for typed trigger monitoring in v0.1
- Apple Speech framework for short voice command recognition in v0.2
- optional local Whisper later
- local JSON/YAML template store

## Template Schema Sketch

```yaml
schema_version: 1
id: review
name: Code Review
triggers:
  typed: [":review"]
  spoken: ["review template", "code review prompt"]
targets:
  generic: |
    Review this change...
  codex: |
    You are Codex reviewing this repo...
variables:
  focus:
    default: correctness, edge cases, tests
```

## Permission Strategy

macOS permission friction is part of the product.

Required permissions by stage:

- v0: Accessibility, for inserting text into the active app
- v0.1: Input Monitoring, for global typed trigger detection
- v0.2: Microphone and Speech Recognition, for voice commands

Failure behavior:

- If Accessibility is denied, copy the expanded template to clipboard and show “Paste now” guidance.
- If Input Monitoring is denied, typed triggers are disabled but command palette still works.
- If Microphone or Speech Recognition is denied, voice triggers are disabled but keyboard flows still work.

## App Compatibility Matrix

The first dogfood pass should test insertion in:

- ChatGPT web
- Claude web
- Cursor
- VS Code
- Terminal or iTerm2
- generic browser text field

Each target should be marked:

- direct insert works
- clipboard fallback works
- broken

## Success Criteria

A first version is successful if:

- the builder uses Flint daily for at least one AI tool
- Flint replaces at least 5 copy-paste prompt templates
- v0 insertion works in at least 3 of: ChatGPT web, Claude web, Cursor, VS Code, Terminal/iTerm2, generic browser text field
- clipboard fallback works anywhere direct insertion fails
- v0.1 typed trigger expansion works for at least 3 high-frequency prompts
- v0.2 voice trigger invocation works reliably enough for short commands
- adding a new template takes under 60 seconds
- the tool feels better than writing an espanso YAML snippet for the same prompt

## Next Steps

1. Create a personal prompt inventory: 10 prompts currently copied, reused, or rewritten often.
2. Prototype the template engine outside the macOS app.
3. Build a tiny macOS menu bar app that inserts selected template text into the active app.
4. Add typed trigger expansion for 3–5 triggers.
5. Add voice command invocation for the same triggers.
6. Dogfood with real AI workflows for one week.
7. Only after daily usage, add transformations like “make this Codex-ready.”

## Source

This README is derived from the approved design document:

`/Users/hippoo/.gstack/projects/unknown/hippoo-unknown-design-20260523-151123-ai-prompt-os.md`
