auto-approves Claude Code's "ready to code?" plan dialog so you stop clicking a button 50 times a day. an optional **Deep Plan** mode also nudges Claude to reason harder *while you're in plan mode* and gives you effort-tier launch aliases. pure bash, no dependencies beyond `jq`.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/auto-approve-claude-plan/main/install.sh)
```

[![bash](https://img.shields.io/badge/bash-pure_shell-93450a.svg?style=flat-square)](https://www.gnu.org/software/bash/)
[![platform](https://img.shields.io/badge/platform-macOS_|_Linux-93450a.svg?style=flat-square)](#)
[![license](https://img.shields.io/badge/license-MIT-grey.svg?style=flat-square)](https://opensource.org/licenses/MIT)

---

## the problem

Claude Code has a plan mode. when Claude finishes writing a plan and calls `ExitPlanMode`, it fires a `PermissionRequest` event and waits for you to click approve. every single time. this hooks into that event and returns `{"behavior":"allow"}` immediately — and also asks Claude Code to land the session in `bypassPermissions` so subsequent tool calls don't prompt either.

## two modes

the installer asks you to pick one:

| mode | what it does |
|:---|:---|
| **1 — Classic** *(default bypass)* | approves every plan instantly and lands the session in `bypassPermissions`. nothing else is touched. install and forget |
| **2 — Deep Plan** *(recommended)* | everything in Classic, **plus** a prompt-level boost: while you are *in* plan mode every prompt is nudged to reason deeply (auto-reverts when you leave plan mode), `effortLevel` is set to `low` as a cheap normal-mode baseline, and two launch aliases (`claude-plan` / `claude-fast`) are added to your shell |

> The old **Orchestrator** mode has been removed. Re-running the installer over an existing Orchestrator install cleans up its `PostToolUse` hook automatically.

### what Deep Plan actually does (and a candid scope note)

Deep Plan is honestly a little **outside the original scope of this tool** — the tool's core job is auto-approving the plan dialog, and this mode is a *prompt thing* bolted on top. It's bundled because it pairs naturally with planning. Be clear-eyed about what it is:

- **In-plan reasoning boost — a prompt nudge, NOT the effort knob.** A `UserPromptSubmit` hook reads `permission_mode`; when it's `"plan"`, it injects deep-reasoning guidance + the `ultrathink` keyword into that turn's context. Per Anthropic's docs, `ultrathink` "adds an in-context instruction" but **the effort level sent to the API is unchanged**. So this deepens *behavior*, not the actual reasoning-effort parameter. The F4 / effort indicator does not move.
- **Why it isn't the real knob:** reasoning effort is **read-only to hooks** — there is no hook output that sets it. The feature request for per-mode effort ([anthropics/claude-code#50323](https://github.com/anthropics/claude-code/issues/50323)) was closed unbuilt, and effort is locked at session launch (not re-read mid-session). A prompt nudge is the only thing a hook *can* do automatically on the plan transition.
- **`effortLevel: low` baseline.** Set only if you haven't already chosen an effort level. It keeps normal (execution) turns cheap, which gives the in-plan boost something to contrast against.
- **Launch aliases — the real max-effort lever.** For genuine maximum effort, you launch a whole session at `max`:
  - `claude-plan` → `CLAUDE_CODE_EFFORT_LEVEL=max claude` (the real knob; also dodges a settings bug where `effortLevel:"max"` is silently downgraded, [#43322](https://github.com/anthropics/claude-code/issues/43322))
  - `claude-fast` → `CLAUDE_CODE_EFFORT_LEVEL=low claude`

So the mental model is: **Classic** auto-approves; **Deep Plan** adds an automatic "think harder while planning" prompt nudge plus convenient effort-tier launchers, with no illusion that it flips the effort dial.

## install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/auto-approve-claude-plan/main/install.sh)
```

or clone first:

```bash
git clone https://github.com/yigitkonur/auto-approve-claude-plan.git /tmp/claude-plan-hook \
  && bash /tmp/claude-plan-hook/install.sh \
  && rm -rf /tmp/claude-plan-hook
```

requires `jq` (`brew install jq` / `apt install jq`). installer is idempotent — re-run to switch modes.

after a **Deep Plan** install, run `source ~/.zshrc` (or open a new shell) to load the aliases, and restart Claude Code so it picks up the new hook.

## how it works

### auto-approve (both modes)
hooks into Claude Code's `PermissionRequest` event with matcher `ExitPlanMode`. the hook script:

1. consumes stdin (required by hook protocol)
2. prints the allow decision to stdout, including the `updatedPermissions` payload requesting `bypassPermissions`
3. Claude Code reads stdout, skips the dialog, starts implementing

### in-plan deepening (Deep Plan only)
a second hook on `UserPromptSubmit` (`~/.claude/hooks/plan-deepen.sh`):

1. reads `permission_mode` from stdin
2. if it's `"plan"`, emits `hookSpecificOutput.additionalContext` with deep-reasoning guidance + `ultrathink`
3. otherwise emits nothing (silent no-op) — so normal/execution turns are unaffected

## what gets installed

```
~/.claude/hooks/claude-plan-hook.sh    — auto-approve hook (both modes)
~/.claude/hooks/plan-deepen.sh         — in-plan reasoning nudge (Deep Plan only)
~/.claude/settings.json                — hook registration + permissions.defaultMode (+ effortLevel for Deep Plan), merged via jq
~/.zshrc (or .bashrc/.profile)         — claude-plan / claude-fast aliases (Deep Plan only), in a clearly-marked block
```

the installer merges into `settings.json` without destroying existing hooks or settings, and brackets the shell aliases with a marker block so they can be cleanly removed.

## project structure

```
auto-approve-claude-plan/
  install.sh                  — interactive installer (Classic / Deep Plan)
  uninstall.sh                — uninstaller (removes hooks, entries, aliases)
  hooks/
    auto-approve-plan.sh      — auto-approve + bypassPermissions (both modes)
    plan-deepen.sh            — UserPromptSubmit in-plan reasoning nudge (Deep Plan)
```

## uninstall

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/auto-approve-claude-plan/main/uninstall.sh)
```

removes both hook scripts, strips our hook entries from `settings.json` (preserving unrelated hooks), and removes the alias block from your shell rc. it intentionally leaves `permissions.defaultMode` and `effortLevel` alone, since those may be your own preferences.

## landing in bypassPermissions

the auto-approve hook emits the documented `updatedPermissions` payload requesting `mode: "bypassPermissions"` for the session, so you don't have to re-approve every subsequent tool call after the plan is accepted.

**the gate (CC `2.1.110+`):** a hook's `setMode: "bypassPermissions"` is a silent no-op *unless the session was launched bypass-eligible* — otherwise it falls through to `acceptEdits`. the `bypassPermissions` value itself is current and correct (verified against the live docs, 2026-06); valid modes are `default | auto | acceptEdits | dontAsk | bypassPermissions | plan`. this gating is documented, intentional behaviour, so it does **not** self-fix.

to satisfy the gate, the installer writes this to your `settings.json` for you:

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

(launching with `claude --permission-mode bypassPermissions` / `--dangerously-skip-permissions` also satisfies it.) make sure `permissions.disableBypassPermissionsMode` is **not** set anywhere — it gates bypass off even when `defaultMode` is set.

### known upstream issues

- [anthropics/claude-code#49525](https://github.com/anthropics/claude-code/issues/49525) — **closed as not-planned.** on `2.1.110+`, `setMode: "bypassPermissions"` from a hook is a no-op unless the session is already bypass-eligible (the gate above). the schema and the value are both correct; this is intentional gating, not a parser bug, and it won't self-fix — the `defaultMode` prerequisite is the fix.
- [anthropics/claude-code#39973](https://github.com/anthropics/claude-code/issues/39973) — `ExitPlanMode` reset the permission mode to `acceptEdits` regardless of the prior session mode; the plan-accept side was addressed in `2.1.118` (#49829). with the gate satisfied, the hook's `setMode` re-applies bypass after plan exit.
- [anthropics/claude-code#50323](https://github.com/anthropics/claude-code/issues/50323) — **closed unbuilt.** request for mode-aware reasoning effort (high in plan, low in execution). this is *why* Deep Plan uses a prompt nudge instead of flipping the effort knob — hooks cannot set effort.
- [anthropics/claude-code#43322](https://github.com/anthropics/claude-code/issues/43322) — `effortLevel: "max"` in `settings.json` is silently swallowed; `max` only applies via `CLAUDE_CODE_EFFORT_LEVEL` or `/effort`. this is why `claude-plan` uses the env var.

## license

MIT
