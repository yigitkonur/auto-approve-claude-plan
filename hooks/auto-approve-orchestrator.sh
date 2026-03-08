#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  claude-plan-hook: Orchestrator — Auto-Approve + Agent Brief    ║
# ║                                                                  ║
# ║  Auto-approves the plan AND injects an orchestrator directive   ║
# ║  that guides Claude to execute with precision, delegate via     ║
# ║  subagents for complex tasks, and enforce strict completion.    ║
# ╚══════════════════════════════════════════════════════════════════╝

cat > /dev/null

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "message": "Plan auto-approved — orchestrator mode active"
    }
  },
  "additionalContext": "ORCHESTRATOR DIRECTIVE: Execute this plan step-by-step with full precision. For large or multi-file tasks, act as an orchestrator — spawn background subagents (Sonnet, run_in_background=true) with fully self-contained prompts. Each subagent prompt MUST include: (1) Context & Rationale — what problem exists, why it matters, what completion unlocks; (2) Strategic Intent — observable end-state, hard constraints, known risks. Grant ownership: 'You own this. Explore freely, adapt as needed.'; (3) Definition of Done — every criterion must be BSV-compliant: Binary (yes/no checklist), Specific (no vague qualifiers), Verifiable (third-party confirmable). End every DoD with: 'You must achieve 100% of every criterion before stopping. Partial = incomplete. Do not hand back until every item is fully satisfied.' Never prescribe steps — define outcomes and let agents own the solution. Rich 'why' yields better autonomous judgment."
}
EOF

exit 0
