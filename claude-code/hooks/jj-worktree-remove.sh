#!/usr/bin/env bash
# WorktreeRemove hook: maps Claude Code worktree removal to jj workspace forget.
# Receives JSON on stdin; exit code is ignored by Claude Code (logged only).
set -euo pipefail

INPUT=$(cat)

# Claude Code may pass 'worktree_path' (the path we returned) or 'name'
WORKTREE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('worktree_path') or d.get('name', ''))
")
SESSION_CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['cwd'])")
WORKSPACE_NAME=$(basename "$WORKTREE_PATH")

REPO_ROOT=$(cd "$SESSION_CWD" && jj root 2>/dev/null) || exit 0

cd "$REPO_ROOT"

jj workspace forget "$WORKSPACE_NAME" 2>/dev/null || true
rm -rf "$WORKTREE_PATH"
