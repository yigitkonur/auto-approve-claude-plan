#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  claude-plan-hook: Orchestrator — Auto-Approve + Agent Brief    ║
# ║                                                                  ║
# ║  Auto-approves the plan AND injects an orchestrator directive   ║
# ║  that guides Claude to execute with precision, delegate via     ║
# ║  subagents for complex tasks, and enforce strict completion.    ║
# ║                                                                  ║
# ║  Also emits setMode="dontAsk" so the post-exit landing mode is   ║
# ║  "dontAsk" instead of the hardcoded "acceptEdits" fallback.      ║
# ║  setMode values: default|acceptEdits|dontAsk|plan (undocumented).║
# ║  bypassPermissions is NOT selectable from a hook.                ║
# ╚══════════════════════════════════════════════════════════════════╝

cat > /dev/null

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "setMode": "dontAsk",
      "message": "Plan auto-approved — orchestrator mode active"
    }
  },
  "additionalContext": "PLAN APPROVED. EXECUTE NOW — STOP ASKING QUESTIONS. You are the orchestrator. Break the plan into ordered WAVES. For each wave: dispatch all independent subtasks IN PARALLEL via subagents in a single tool message; wait for the entire wave to finish; then launch the next wave. NEVER interleave waves. Before spawning any subagent: READ ~/MISSION_PROTOCOL.md FIRST. Internalize its principles. Apply them in every subagent brief, but DO NOT name the file in the brief — bake the principles in directly. Every brief carries: rich context (the why), an observable end state, and a binary/specific/verifiable Definition of Done ending with '100% completion required — partial = failure. Do not return until every criterion is met.' DO NOT spawn agents for trivial or sequential work — single-agent execution is cheaper. Match parallelism to actual independence. Wasted swarms = wasted tokens. Finish to 100% before reporting. No mid-task pauses. No 'should I continue?' No premature summaries. Verify what you claim. Done means done."
}
EOF

exit 0
