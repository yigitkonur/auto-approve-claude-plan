#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  claude-plan-hook: Orchestrator — event-branching                ║
# ║                                                                  ║
# ║  Wired to TWO hook events (registered by install.sh):            ║
# ║                                                                  ║
# ║    PermissionRequest / ExitPlanMode                              ║
# ║      → emits decision allow + updatedPermissions requesting      ║
# ║        bypassPermissions for the session (documented schema).    ║
# ║                                                                  ║
# ║    PostToolUse / ExitPlanMode                                    ║
# ║      → emits hookSpecificOutput.additionalContext (nested)       ║
# ║        with the orchestrator directive. PostToolUse is the only  ║
# ║        documented event after plan exit that injects text into   ║
# ║        the model's next turn — PermissionRequest does NOT.       ║
# ║                                                                  ║
# ║  Schema source: code.claude.com/docs/en/hooks                    ║
# ║                                                                  ║
# ║  THE GATE (CC 2.1.110+): a hook setMode:"bypassPermissions" is   ║
# ║  a silent no-op unless the session was launched bypass-eligible  ║
# ║  (#49525, closed not-planned — documented behaviour, not a bug   ║
# ║  that self-fixes). The "bypassPermissions" value itself is       ║
# ║  current/unchanged.                                              ║
# ║                                                                  ║
# ║  Prerequisite (set by install.sh): permissions.defaultMode =     ║
# ║  "bypassPermissions" in settings.json (or launch with            ║
# ║  `claude --permission-mode bypassPermissions`), and ensure       ║
# ║  permissions.disableBypassPermissionsMode is NOT set.            ║
# ║                                                                  ║
# ║  The script reads stdin, parses .hook_event_name with jq, and    ║
# ║  branches accordingly. Unknown events → silent no-op.            ║
# ╚══════════════════════════════════════════════════════════════════╝

set -u

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)

case "$event" in
  PermissionRequest)
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "updatedPermissions": [
        {"type": "setMode", "mode": "bypassPermissions", "destination": "session"}
      ],
      "message": "Plan auto-approved — orchestrator mode active"
    }
  }
}
EOF
    ;;

  PostToolUse)
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "PLAN APPROVED. EXECUTE NOW — STOP ASKING QUESTIONS. You are the orchestrator. Break the plan into ordered WAVES. For each wave: dispatch all independent subtasks IN PARALLEL via subagents in a single tool message; wait for the entire wave to finish; then launch the next wave. NEVER interleave waves. Before spawning any subagent: READ ~/MISSION_PROTOCOL.md FIRST. Internalize its principles. Apply them in every subagent brief, but DO NOT name the file in the brief — bake the principles in directly. Every brief carries: rich context (the why), an observable end state, and a binary/specific/verifiable Definition of Done ending with '100% completion required — partial = failure. Do not return until every criterion is met.' DO NOT spawn agents for trivial or sequential work — single-agent execution is cheaper. Match parallelism to actual independence. Wasted swarms = wasted tokens. Finish to 100% before reporting. No mid-task pauses. No 'should I continue?' No premature summaries. Verify what you claim. Done means done."
  }
}
EOF
    ;;

  *)
    : # silent no-op for unrecognized events
    ;;
esac

exit 0
