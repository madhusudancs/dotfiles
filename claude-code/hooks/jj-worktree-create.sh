#!/usr/bin/env bash
# WorktreeCreate hook: maps Claude Code worktree creation to jj workspace add.
# Receives JSON on stdin with: session_id, cwd, hook_event_name, name
# Must print the worktree path to stdout and exit 0.
set -euo pipefail

INPUT=$(cat)

NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])")
SESSION_CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['cwd'])")

# Find jj repo root from session cwd
REPO_ROOT=$(cd "$SESSION_CWD" && jj root 2>/dev/null) || {
    echo "jj-worktree-create: could not find jj repo root from $SESSION_CWD" >&2
    exit 1
}

# Follow Claude Code's default worktree path convention
WORKTREE_PATH="${REPO_ROOT}/.claude/worktrees/${NAME}"

cd "$REPO_ROOT"

# Avoid name collision if workspace already exists
WORKSPACE_NAME="$NAME"
if jj workspace list 2>/dev/null | grep -q "^${WORKSPACE_NAME}:"; then
    WORKSPACE_NAME="${NAME}-$$"
    WORKTREE_PATH="${REPO_ROOT}/.claude/worktrees/${WORKSPACE_NAME}"
fi

mkdir -p "$(dirname "$WORKTREE_PATH")"
jj workspace add --name "$WORKSPACE_NAME" "$WORKTREE_PATH" >&2 || {
    echo "jj-worktree-create: jj workspace add failed" >&2
    exit 1
}

echo "$WORKTREE_PATH"
