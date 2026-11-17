#!/usr/bin/env bash
# Prints the git state of a workspace built by check-req-workspace.sh, so that the
# state before and after an eval run can be compared and graded.
#
# Usage:  bash tests/eval-fixtures/dump-state.sh <folder that holds ws/ and remotes/>
set -u
T="$(cd "${1:?usage: dump-state.sh <fixture folder>}" && (pwd -W 2>/dev/null || pwd))"
W="$T/ws"
cd "$W" || exit 1
rel() { sed "s#$T#<fixture>#g"; }

echo "## root checkout"
echo "branch: $(git branch --show-current || true)"
echo "status:"; git status --porcelain=v1 | sed 's/^/  /'
echo "worktrees:"; git worktree list | rel | sed 's/^/  /'
echo
echo "## workspace branches (local and remote, with tip)"
git for-each-ref --format='%(refname:short) %(objectname:short)' refs/heads refs/remotes | sed 's/^/  /'
echo
echo "## request files on each request branch"
for b in $(git for-each-ref --format='%(refname:short)' refs/heads | grep -E 'REQ-|^hotfix/'); do
  for f in $(git ls-tree --name-only "$b" reqs/ reqs/done/ | grep -E 'REQ-[0-9]+.*\.md$'); do
    echo "- $b:$f"
    git show "$b:$f" | sed -n '2,10p' | grep -E '^(status|branch|project-branch|priority|type):' | sed 's/^/    /'
  done
  echo "    gitlinks: $(for p in SSLib SSDisp; do printf '%s=%s ' "$p" "$(git rev-parse --short "$b:projects/$p")"; done)"
  echo "    log $(git merge-base develop "$b" | cut -c1-7)..$b:"
  git log --format='      %h %s%n%w(0,8,8)%b' "develop..$b" | sed '/^ *$/d'
done
for p in SSLib SSDisp; do
  echo
  echo "## project $p"
  echo "HEAD: $(git -C "projects/$p" rev-parse --short HEAD) branch: $(git -C "projects/$p" branch --show-current)"
  echo "status:"; git -C "projects/$p" status --porcelain=v1 | sed 's/^/  /'
  echo "worktrees:"; git -C "projects/$p" worktree list | rel | sed 's/^/  /'
  echo "branches:"; git -C "projects/$p" for-each-ref --format='%(refname:short) %(objectname:short)' refs/heads refs/remotes | sed 's/^/  /'
  for b in $(git -C "projects/$p" for-each-ref --format='%(refname:short)' refs/heads | grep -v -E '^(master|develop)$'); do
    echo "log origin/develop..$b:"
    git -C "projects/$p" log --format='  %h %s%n%w(0,4,4)%b' "origin/develop..$b" | sed '/^ *$/d'
    echo "files changed:"; git -C "projects/$p" diff --name-status "origin/develop...$b" | sed 's/^/  /'
    for f in $(git -C "projects/$p" diff --name-only "origin/develop...$b"); do
      echo "  $f: $(git -C "projects/$p" show "$b:$f" 2>/dev/null | tr '\n' '|')"
    done
  done
done
