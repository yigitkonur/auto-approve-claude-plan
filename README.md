auto-approves Claude Code's "ready to code?" plan dialog so you stop clicking a button 50 times a day. orchestrator mode injects a directive that makes Claude execute with precision and delegate complex tasks via subagents. pure bash, no dependencies beyond `jq`.

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
| **1 — Classic** | approves every plan instantly. no frills, no extras. install and forget |
| **2 — Orchestrator** *(recommended)* | approves instantly and injects an orchestrator directive into Claude's context — makes it execute step-by-step, spawn background subagents for complex tasks, and enforce strict BSV completion criteria |

### what the orchestrator directive does

when a plan is approved in orchestrator mode, Claude receives context that tells it to:

- **execute step-by-step** with full precision, no shortcuts
- **act as an orchestrator** for large/multi-file tasks — spawn background subagents with self-contained prompts
- **structure every subagent prompt** with: context & rationale, strategic intent (outcomes not steps), and a BSV-compliant definition of done
- **enforce 100% completion** — partial = incomplete, no handing back until every criterion is satisfied
- **never prescribe steps** — define outcomes and let agents own the solution

this is particularly useful if you use Claude Code with background agents, teams, or complex multi-file refactors.

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

## how it works

hooks into Claude Code's `PermissionRequest` event with matcher `ExitPlanMode`. the hook script:

1. consumes stdin (required by hook protocol)
2. prints the allow decision to stdout
3. (orchestrator mode) includes an `additionalContext` field with the orchestrator directive
4. Claude Code reads stdout, skips the dialog, starts implementing

## what gets installed

```
~/.claude/hooks/claude-plan-hook.sh    — the active hook script (one of two modes)
~/.claude/settings.json                — hook registration merged via jq
```

the installer merges into `settings.json` without destroying existing hooks or settings.

## project structure

```
auto-approve-claude-plan/
  install.sh                        — interactive installer
  uninstall.sh                      — uninstaller
  hooks/
    auto-approve-plan.sh            — mode 1: classic auto-approve
    auto-approve-orchestrator.sh    — mode 2: auto-approve + orchestrator directive
```

## uninstall

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/auto-approve-claude-plan/main/uninstall.sh)
```

or manually:

```bash
rm ~/.claude/hooks/claude-plan-hook.sh
# then remove the ExitPlanMode entry from ~/.claude/settings.json
```

## landing in bypassPermissions

both hooks emit the documented `updatedPermissions` payload requesting `mode: "bypassPermissions"` for the session, so you don't have to re-approve every subsequent tool call after the plan is accepted.

**the gate (CC `2.1.110+`):** a hook's `setMode: "bypassPermissions"` is a silent no-op *unless the session was launched bypass-eligible* — otherwise it falls through to `acceptEdits`. the `bypassPermissions` value itself is current and correct (verified against the live docs, 2026-06); valid modes are `default | auto | acceptEdits | dontAsk | bypassPermissions | plan`. this gating is documented, intentional behaviour, so it does **not** self-fix.

to satisfy the gate, the installer now writes this to your `settings.json` for you:

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

## compatibility note

issue #1 reported a `jq sub()` regex bug in the old Craft integration. that code path no longer exists in this repository because Craft support was removed entirely. the current scripts do not use `sub()` or Craft payload generation.

## license

MIT
