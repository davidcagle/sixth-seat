#!/bin/bash
# session-end-automerge.sh
#
# Fired by Claude Code's SessionEnd hook. If the session was on a
# `claude/*` branch inside a worktree, fast-forward-merge that branch
# into main and clean up the worktree + branch.
#
# Bails safely (exit 0) on anything ambiguous — never destroys
# uncommitted work, never force-merges.

set -u

log() { echo "[session-end-automerge] $*" >&2; }

WT=$(pwd)

# Are we even in a git worktree / repo?
BR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
  log "not a git repo — skipping"
  exit 0
}

# Only act on claude/* session branches. Leaves manual branches alone.
case "$BR" in
  claude/*) ;;
  *)
    log "branch '$BR' is not a claude/* session branch — skipping"
    exit 0
    ;;
esac

# Refuse to touch anything if the working tree or index is dirty.
# Uncommitted work on a session branch is the user's problem to
# resolve; auto-merging would lose it.
if ! git diff --quiet || ! git diff --cached --quiet; then
  log "uncommitted changes on '$BR' — leaving worktree intact, NOT merging"
  exit 0
fi

# Find the main worktree's path so we can run git commands from there.
# NOTE: worktree paths can contain spaces, so we can't use awk $2 — strip
# the "worktree " prefix off the whole line instead.
MAIN_WT=$(git worktree list --porcelain \
  | awk '/^worktree /{sub(/^worktree /,""); wt=$0} /^branch refs\/heads\/main$/{print wt; exit}')

if [ -z "${MAIN_WT:-}" ]; then
  log "could not locate main worktree — leaving '$WT' intact"
  exit 0
fi

if [ "$MAIN_WT" = "$WT" ]; then
  log "already in main worktree — nothing to do"
  exit 0
fi

if ! cd "$MAIN_WT" 2>/dev/null; then
  log "could not cd into main worktree '$MAIN_WT' — leaving '$WT' intact"
  exit 0
fi

# Try fast-forward only. If main has diverged, the user needs to
# rebase/merge manually.
if ! git merge --ff-only "$BR" >/dev/null 2>&1; then
  log "cannot fast-forward '$BR' into main — leaving '$WT' intact"
  exit 0
fi

log "fast-forward merged '$BR' into main"

# Merge succeeded — remove the worktree and delete the branch.
# CWD is already MAIN_WT from the cd above, so we're not trying to
# delete our own CWD.
if ! git worktree remove --force "$WT" 2>/dev/null; then
  log "merged OK but failed to remove worktree '$WT' (may be locked)"
  exit 0
fi

if ! git branch -D "$BR" >/dev/null 2>&1; then
  log "merged and removed worktree, but failed to delete branch '$BR'"
  exit 0
fi

log "cleaned up worktree '$WT' and branch '$BR'"
exit 0
