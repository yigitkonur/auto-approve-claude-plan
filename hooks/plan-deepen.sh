#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  plan-deepen: UserPromptSubmit hook — deepen reasoning in PLAN    ║
# ║  MODE, no-op otherwise. The "Deep Plan" half of this tool.        ║
# ║                                                                    ║
# ║  WHY A PROMPT NUDGE AND NOT AN EFFORT SETTING:                     ║
# ║  Reasoning effort (the F4 knob) is READ-ONLY to hooks. There is    ║
# ║  NO hook output that sets effort — `updatedPermissions`/`setMode`  ║
# ║  changes permission mode only. The feature request for per-mode    ║
# ║  effort (anthropics/claude-code#50323) was closed unbuilt, and     ║
# ║  effort is locked at session launch (not re-read mid-session).     ║
# ║  So the only automatic, plan-mode-gated lever is injecting         ║
# ║  in-context guidance via hookSpecificOutput.additionalContext.     ║
# ║                                                                    ║
# ║  Mechanism: read permission_mode from stdin; when it is "plan",    ║
# ║  inject deep-reasoning guidance + the `ultrathink` keyword (the    ║
# ║  only live keyword — "think"/"think harder" are no longer magic).  ║
# ║  Per the docs, ultrathink deepens reasoning in-context but does    ║
# ║  NOT change the API effort parameter: this is a behavioral nudge,  ║
# ║  not a true effort bump. For a real max-effort knob, launch via    ║
# ║  the `claude-plan` alias (CLAUDE_CODE_EFFORT_LEVEL=max) that the   ║
# ║  installer adds to your shell rc.                                  ║
# ║                                                                    ║
# ║  Framing: guidance is phrased as plain reasoning instruction (not  ║
# ║  out-of-band system commands) to avoid tripping CC's              ║
# ║  prompt-injection defenses. The plan ceiling (~2000 lines) is a    ║
# ║  maximum, not a target.                                            ║
# ║                                                                    ║
# ║  Schema source: code.claude.com/docs/en/hooks                      ║
# ╚══════════════════════════════════════════════════════════════════╝

set -u

input=$(cat)
mode=$(printf '%s' "$input" | jq -r '.permission_mode // "default"' 2>/dev/null)

if [ "$mode" = "plan" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: "This is a PLANNING turn. Reason as deeply and rigorously as the task allows before writing anything: map the architecture, trace data flow, enumerate edge cases, failure modes, dependencies, and trade-offs, and weigh more than one approach. Prefer correctness and completeness of thinking over speed. Keep the resulting plan focused and under ~2000 lines (a hard ceiling, not a target — be concise within deep reasoning). ultrathink"
    }
  }'
fi

exit 0
