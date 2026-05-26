# Design

## Source of truth
- Status: Active draft
- Last refreshed: 2026-05-24
- Primary product surfaces:
  - Native macOS menu bar app
  - Global-hotkey Quick Palette for typed prompt intents
  - Raycast-style command list with one intent input, prompt results, and a copy action bar
  - Template list, intent input, copy status
  - Typed-trigger feedback states
  - Future public/documentation surface for Flint positioning
- Evidence reviewed:
  - `README.md` — product positioning, target users, v0/v0.1/v0.2/v1 roadmap, permissions, quick-start flow
  - `Sources/FlintApp/CommandPaletteWindow.swift` — current SwiftUI/AppKit Quick Palette, window chrome, style tokens, intent input, command list, and copy/status action bar
  - `Sources/FlintApp/AppDelegate.swift` — menu bar app, `Flint` status item, command palette menu, typed-trigger startup
  - `Sources/FlintApp/FlintApp.swift` — Settings-only native app shell
  - `templates/*.yaml` — current template names, descriptions, typed/spoken triggers, targets
  - `docs/compatibility-matrix.md` — target app compatibility and manual copy/paste protocol
  - `docs/dogfood-log.md` — dogfood validation threshold
- Evidence vs inference:
  - Evidence: Flint is currently a macOS dogfood prototype for reusable AI prompt templates, hotkey palette, local YAML templates, and typed triggers.
  - Inference: The durable visual direction should be minimal, documentation-like, and fast rather than decorative, because the product sits before the AI tool and should disappear after copying.

## Brand
- Personality:
  - Quiet, utilitarian, native, precise.
  - Feels like a well-rendered README or system utility, not a marketing-heavy chatbot.
  - Flint should read as “prompt infrastructure” rather than “AI companion.”
- Trust signals:
  - Local templates first.
  - Clear macOS permission messaging.
  - Clipboard fallback is explicit and predictable.
  - No hidden cloud/sync assumptions in v0.
- Avoid:
  - borrowed third-party naming, mascots, CLI examples, URLs, or copyright.
  - Strong brand colors, gradients, heavy shadows, glassy effects that obscure text, and decorative chrome.
  - Chatbot-like personality or anthropomorphic microcopy.

## Product goals
- Goals:
  - Make recurring AI prompt reuse faster than manual copy-paste.
  - Provide one reliable Quick Palette for typed intent matching and copying templates.
  - Support typed triggers like `:debug`, `:review`, `:plan`, `:codex`, and `:critic` without surprising the user.
  - Make local template behavior understandable and dogfoodable.
- Non-goals:
  - Full prompt-template editor in v0.
  - Full voice dictation or AI transformations in v0.
  - Marketplace, sync, teams, account chrome, or cloud model management.
  - Decorative brand system that competes with the user’s destination app.
- Success signals:
  - User can open the Quick Palette with `⌘⇧Space`, type an intent, select a prompt command, and copy without confusion.
  - User understands permission/fallback status messages.
  - Dogfood log shows Flint is faster and less annoying than copy-paste for recurring prompts.
  - At least three target apps are manually verified before claiming v0 wedge validation.

## Personas and jobs
- Primary personas:
  - AI-heavy developers using ChatGPT, Claude, Codex, Cursor, Claude Code, or similar tools.
  - Builders who already reuse prompts manually or through snippets/text expansion.
- User jobs:
  - “Copy my standard code-review prompt from here.”
  - “Turn this idea into a Codex-ready task.”
  - “Get a debugging/planning/critic prompt without leaving flow.”
  - “Use the same prompt library across apps.”
- Key contexts of use:
  - While typing in a browser AI chat field.
  - While using Cursor/VS Code/editor chat inputs.
  - While writing specs, issues, or implementation plans.
  - During dogfood workflows where speed and reliability matter more than visual novelty.

## Information architecture
- Primary navigation:
  - macOS menu bar item: `Flint`.
  - Menu actions: Open Quick Palette, Quit Flint.
  - Global hotkey: `⌘⇧Space`.
  - Typed triggers inside arbitrary text fields.
- Core routes/screens:
  - Quick Palette window.
  - Intent input and matched-action list.
  - Copy action/status panel.
- Content hierarchy:
  1. Product title: “Flint.”
  2. Intent input: “Search prompts and commands...”
  3. Matched actions/templates.
  4. Primary copy action and status feedback.

## Design principles
- Principle 1: The UI is a tool, not a destination.
  - Flint is invoked, used quickly, and dismissed.
  - The prompt content and selected template are more important than decorative chrome.
- Principle 2: Documentation-like clarity beats “AI app” theatrics.
  - Prefer flat surfaces, readable type, obvious controls, and predictable state changes.
  - Use a narrow, restrained visual vocabulary.
- Principle 3: Native macOS behavior remains trustworthy.
  - Window controls, focus, keyboard navigation, menu bar behavior, and permission flows should feel native.
- Principle 4: Local-first trust must be visible in copy and states.
  - Avoid implying sync, cloud, or account features before they exist.
- Tradeoffs:
  - If visual polish conflicts with readability or native controls, choose readability/native controls; keep the paper-white palette while preserving usable AppKit window controls.
  - If custom chrome creates hit-testing or drag issues, use AppKit chrome and align colors as far as safely possible.

## Visual language
- Color:
  - Core direction: minimal paper-white service/UI inspired by documentation surfaces.
  - `colors.canvas`: `#ffffff` — default public/documentation canvas and preferred future app surface where native constraints allow.
  - `colors.primary`: `#000000` — primary CTA, important text, and icon fill.
  - `colors.ink-deep`: `#090909` — pressed primary action.
  - `colors.surface-soft`: `#fafafa` — search pill, install/command chip, soft row fills.
  - `colors.surface-dark`: `#171717` — rare inverted emphasis surface; use at most once per viewport.
  - `colors.hairline`: `#e5e5e5` — borders and dividers.
  - `colors.hairline-strong`: `#d4d4d4` — stronger separation only when needed.
  - `colors.body`: `#737373` — default supporting copy.
  - `colors.mute`: `#a3a3a3` — captions, placeholder text, low-emphasis status.
  - `colors.on-dark`: `#ffffff`; `colors.on-dark-mute`: `rgba(255,255,255,0.7)`.
  - Focus ring may use system/browser blue only as a transient accessibility cue; it is not a brand color.
- Typography:
  - Display/headings: SF Pro Rounded where available; fallback `system-ui`/`-apple-system`.
  - Body/buttons/captions: system sans.
  - Code/templates: system monospace (`SFMono-Regular`, Menlo, Monaco, Consolas fallback).
  - Scale: 36 / 30 / 24 / 20 / 18 / 16 / 14 / 12 px.
  - Avoid expressive display typography beyond rounded native/system heading feel.
- Spacing/layout rhythm:
  - Base unit: 8px, with 2/4/6px allowed for tight inline details.
  - Major surfaces should breathe; avoid dense rows unless the command palette is constrained.
  - Palette internal padding target: 22px vertical × 28px horizontal where window size permits.
- Shape/radius/elevation:
  - Interactive elements: pill radius (`9999px`) by default.
  - Command rows use compact rounded selection fills.
  - Native command palette may use softer macOS radii only when required by platform conventions, but avoid arbitrary oversized rounded cards.
  - Elevation is border/color, not shadow. Use 1px hairlines; no heavy drop shadows.
- Motion:
  - Subtle entrance/focus transitions only.
  - No decorative motion or long animations.
  - Respect reduced motion; do not require animation to understand state.
- Imagery/iconography:
  - Use a minimal Flint spark mark or simple line icons if needed.
  - Do not use borrowed third-party mascot imagery or references.
  - macOS traffic-light dots belong only to native window chrome or terminal mockup metaphors.

## Components
- Existing components to reuse:
  - `CommandPaletteWindowController` / `CommandPaletteView` in `Sources/FlintApp/CommandPaletteWindow.swift`.
  - `TemplateRepository` and YAML template metadata for row names/descriptions.
  - AppKit status item/menu from `AppDelegate.swift`.
- New/changed components:
  - `quick-palette-window`: borderless floating macOS window with Raycast-like rounded chrome.
  - `intent-input`: large top search field for prompt intents.
  - `command-row`: icon, prompt name, trigger/detail, and trailing command type.
- `action-bar`: bottom settings affordance, Copy action, and Return hint.
  - `status-caption`: low-emphasis feedback explaining copy states.
- Variants and states:
  - Search: default, focused, empty results.
  - Template row: default, selected, keyboard-focused, filtered-hidden.
  - Action: enabled, pressed, disabled/empty prompt, success copied, fallback copied, permission needed.
  - Window: active/inactive; borderless floating palette remains draggable by background.
- Token/component ownership:
  - `DESIGN.md` owns product-level design decisions and tokens.
  - SwiftUI local tokens may exist in `CommandPaletteWindow.swift` while the app is small.
  - If tokens spread beyond one file, extract a small `FlintTheme` module/file rather than duplicating values.

## Accessibility
- Target standard:
  - WCAG AA contrast for text and controls.
  - Native macOS keyboard/focus expectations.
- Keyboard/focus behavior:
  - `⌘⇧Space` opens palette.
  - Search should receive focus on open.
  - Arrow navigation and Return-to-copy are desired future improvements.
  - Escape should close the palette in a future pass if not already handled by AppKit defaults.
- Contrast/readability:
  - Command names and triggers must remain more important than glass/material effects.
  - Do not use translucent panels that lower prompt readability.
- Screen-reader semantics:
  - Template rows should expose name and description.
  - Copy controls should include clear accessibility labels.
  - Status messages should be readable and concise.
- Reduced motion and sensory considerations:
  - Keep entrance animation short and non-essential.
  - Avoid ambient/glow effects that imply meaning.

## Responsive behavior
- Supported breakpoints/devices:
  - Native macOS 14+ desktop app.
- Primary size currently ~760×480 to stay close to Raycast's compact command palette footprint.
  - Future public/docs surfaces should support desktop/tablet/mobile breakpoints.
- Layout adaptations:
  - Palette: search full width; command results occupy the main body.
  - Template rows should avoid truncating prompt names when reasonable; triggers and types may truncate first.
- Touch/hover differences:
  - macOS pointer/keyboard first.
  - Hover states are optional and should be subtle.
  - Touch behavior is not a v0 native-app requirement.

## Interaction states
- Loading:
  - Template load should feel instant. If loading becomes async, show a low-emphasis “Loading templates…” state.
- Empty:
  - No templates: “No local templates found.”
  - No search results: show empty result text rather than a blank panel.
- Error:
  - Template load/render errors should name the failure in plain language without stack traces.
  - Typed-trigger permission errors should explain Accessibility permission; the command palette should stay copy-only and reliable.
- Success:
  - Copy: “Copied expanded prompt. Paste now in the active app.”
- Disabled:
  - Copy disabled if no rendered prompt exists.
- Offline/slow network:
  - v0 has no network dependency; offline should not change template copying.

## Content voice
- Tone:
  - Direct, terse, tool-like.
  - No hype, no anthropomorphic assistant language.
- Terminology:
  - Use “template,” “trigger,” “intent,” “expanded prompt,” “copy,” and “clipboard.”
  - Avoid “model marketplace,” “agent cloud,” or sync/account terms before those features exist.
- Microcopy rules:
  - One sentence where possible.
  - Status text should tell the user what happened and what to do next.
  - Error messages should be actionable.

## Implementation constraints
- Framework/styling system:
  - Native SwiftUI + AppKit.
  - macOS 14+ per `Package.swift`.
  - No new UI dependencies without explicit product need.
- Design-token constraints:
  - Keep tokens local while UI is one surface.
  - Use `DESIGN.md` names in comments or code organization when extracting tokens.
  - Avoid introducing a second conflicting dark/liquid-glass system unless `DESIGN.md` is updated first.
- Performance constraints:
  - Palette open/search should feel instant for the small local template library.
  - Template rendering must stay synchronous/simple unless library size changes.
- Compatibility constraints:
  - Maintain menu bar app behavior.
  - Typed-trigger expansion may depend on Accessibility permission; manual palette flow is copy-only and should stay reliable without Accessibility.
  - Native window controls must remain clickable and draggable.
- Test/screenshot expectations:
  - Run `swift build` and `swift test` after UI changes.
  - Use manual visual smoke via `swift run FlintApp` for palette chrome, focus, selection, and copy status.
  - Record target-app copy/paste evidence in `docs/compatibility-matrix.md`.
  - Record real dogfood usage in `docs/dogfood-log.md` before v0 validation claims.

## Open questions
- [x] Native command palette adopts the paper-white design now. Decision made 2026-05-24; implementation should use `colors.canvas`, black primary CTA, soft surfaces, and hairline borders rather than a dark utility palette.
- [x] Copy is the only primary action in the v0 UI. Decision made 2026-05-24; direct Insert should not compete with the keyboard intent flow.
- [ ] Should template variables become editable in the palette before v0.1? / owner: product / impact: form/input component scope.
- [ ] What should the Flint spark mark look like, and does it need to appear in the native palette or only public/docs surfaces? / owner: brand / impact: iconography and window/menu branding.
