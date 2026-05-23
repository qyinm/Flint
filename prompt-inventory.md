# Flint Prompt Inventory

This inventory lists recurring AI prompts the builder copies, reuses, or rewrites often. It is the Gate 0 artifact for Flint v0: if at least 5 prompts are not worth templating, app implementation should stop and the wedge should be revisited.

| # | prompt_name | prompt_body | typed_trigger | spoken_trigger | target_tools | frequency |
|---:|---|---|---|---|---|---|
| 1 | Code Review | Review this code change. Focus on correctness, edge cases, regressions, test gaps, and the smallest safe fix. Return critical issues first, then suggestions. | `:review` | review template | Codex, Claude, ChatGPT, Cursor | daily |
| 2 | Bug Debugger | Diagnose this bug from the symptoms, logs, and code context. Identify likely root causes, evidence needed, and the smallest verification path before proposing a fix. | `:debug` | debug prompt | Codex, Claude, ChatGPT, Cursor | daily |
| 3 | Implementation Plan | Turn this idea into a concrete implementation plan with assumptions, non-goals, acceptance criteria, risks, and verification steps. | `:plan` | planning prompt | Codex, Claude, ChatGPT | several times/week |
| 4 | Codex Task | Convert this request into a Codex-ready task brief with target result, constraints, files to inspect, acceptance criteria, and validation commands. | `:codex` | make Codex task | Codex | daily |
| 5 | Seed Spec | Create or refine a Seed-style YAML specification with goal, problem statement, milestones, non-goals, constraints, acceptance criteria, and exit conditions. | `:seed` | seed spec | ChatGPT, Claude, Codex | weekly |
| 6 | PRD Critic | Critique this PRD or plan. Find vague claims, missing success/falsification criteria, hidden assumptions, scope creep, and weak verification. | `:critic` | critic prompt | Claude, ChatGPT, Codex | several times/week |
| 7 | Korean Rewrite | Rewrite this in natural Korean while preserving technical meaning, directness, and decision boundaries. Offer a concise version and a polished version. | `:ko` | Korean rewrite | ChatGPT, Claude | several times/week |
| 8 | Acceptance Criteria | Add testable acceptance criteria to this feature request. Include file review, automated tests, manual checks, and explicit non-goals where relevant. | `:ac` | acceptance criteria | Codex, Claude, ChatGPT | weekly |
| 9 | Architecture Tradeoff | Compare implementation options. State decision drivers, viable alternatives, tradeoffs, rejected options, and an ADR-style recommendation. | `:adr` | architecture tradeoff | Claude, Codex, ChatGPT | weekly |
| 10 | Release Notes | Summarize these changes for a user-facing release note and an internal engineering note. Include risks, migration notes, and validation evidence. | `:release` | release notes | ChatGPT, Claude | occasional |

## Gate 0 result

- Viable recurring prompts identified: 10
- Prompts worth templating for v0: at least 5
- Selected initial v0 templates: Code Review, Bug Debugger, Implementation Plan, Codex Task, PRD Critic
- Deferred metadata only: typed_trigger and spoken_trigger are placeholders for future v0.1/v0.2; v0 does not implement typed or voice trigger invocation.
