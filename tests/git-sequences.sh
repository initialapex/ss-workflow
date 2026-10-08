#!/usr/bin/env bash
# Runs the git command sequences that the ss-workflow skills prescribe, and checks
# that git behaves as the skill files say. It tests git, not the agent: it does not
# start Claude, and it does not cover gh / glab.
#
# The script builds a throwaway sandbox in a temporary folder: one bare repository as
# the remote, clone A as the root checkout, and clone B as a second machine. Three
# more repositories cover the other setups: C has no remote at all, D has a remote
# that it does not push to (push-policy: never), and E has a remote that refuses
# pushes to develop (a protected branch). It never touches this repository.
#
# Usage:  bash tests/git-sequences.sh
#         KEEP=1 bash tests/git-sequences.sh    # keep the sandbox for inspection
#
# Run it again whenever a skill's git steps change. Lines marked NOTE record how git
# behaved where the skills only need to know the behavior, not to enforce it.
S="$(mktemp -d "${TMPDIR:-/tmp}/ss-workflow-git-XXXXXX")" || exit 1
cd "$S" || exit 1
echo "sandbox: $S"
PASS=0; FAIL=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
ng()   { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
yes_() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ng "$d"; fi; }
no_()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ng "$d"; else ok "$d"; fi; }
eq_()  { if [ "$2" = "$3" ]; then ok "$1"; else ng "$1 (got '$2', want '$3')"; fi; }
sec()  { echo; echo "== $1"; }
status_of() { git show "$1" 2>/dev/null | sed -n 's/^status: //p' | head -1; }
setstatus() { sed -i "s/^status: .*/status: $2/" "$1"; }
mkreq() { # id slug type
  cat > "reqs/REQ-$1-20261007-$2.md" <<EOF
---
id: REQ-$1
title: $2
status: draft
type: $3
priority: normal
branch:
created: 2026-10-07
---

# $2

## Spec

- [ ] criterion one

## Original

original text of $2

## Q&A

## Notes
EOF
}
initrepo() { # creates master + develop with a first commit in the current folder
  git checkout -q -b master
  mkdir -p reqs/done src
  echo "ss-workflow-version: 0.1.0" > AGENTS.md
  touch reqs/done/.gitkeep
  echo "0.1.0" > src/version.txt
  echo "hello" > src/app.txt
  printf ".claude/worktrees/\n" > .gitignore
  git add -A 2>/dev/null; git commit -q -m "chore: initial commit"
  git branch develop
}
localreq() { # id slug type  -> request is ready on the local develop, nothing pushed
  git checkout -q -b "req/REQ-$1-$2" develop
  mkreq "$1" "$2" "$3"
  git add -A 2>/dev/null; git commit -q -m "docs(reqs): add draft REQ-$1 $2" -m "Refs: REQ-$1"
  setstatus "reqs/REQ-$1-20261007-$2.md" ready
  git commit -q -am "docs(reqs): mark REQ-$1 ready" -m "Refs: REQ-$1"
  git checkout -q develop
  git merge -q --no-ff "req/REQ-$1-$2" -m "Merge req/REQ-$1-$2 into develop" -m "$2" -m "Refs: REQ-$1"
  git branch -q -d "req/REQ-$1-$2"
}

A="$S/A"; B="$S/B"

sec "setup: bare remote, clone A (root checkout), master + develop"
git init -q --bare remote.git
git clone -q remote.git A 2>/dev/null
cd "$A"
git checkout -q -b master
mkdir -p reqs/done src
echo "ss-workflow-version: 0.1.0" > AGENTS.md
touch reqs/done/.gitkeep
echo "0.1.0" > src/version.txt
echo "hello" > src/app.txt
printf ".claude/worktrees/\n" > .gitignore
git add -A 2>/dev/null; git commit -q -m "chore: initial commit"
git branch develop
git push -q -u origin master develop 2>/dev/null
git checkout -q develop
eq_ "root checkout is on develop" "$(git branch --show-current)" "develop"

# ---------------------------------------------------------------- new-req
sec "new-req: req/ branch, draft, ready, merge into develop"
newreq() { # id slug type  -> leaves develop with the request as ready
  git checkout -q -b "req/REQ-$1-$2" develop
  git push -q -u origin "req/REQ-$1-$2" 2>/dev/null
  mkreq "$1" "$2" "$3"
  git add -A 2>/dev/null; git commit -q -m "docs(reqs): add draft REQ-$1 $2" -m "Refs: REQ-$1"
  git push -q 2>/dev/null
  setstatus "reqs/REQ-$1-20261007-$2.md" ready
  git commit -q -am "docs(reqs): mark REQ-$1 ready" -m "Refs: REQ-$1"; git push -q 2>/dev/null
  git checkout -q develop; git pull -q --ff-only 2>/dev/null
  git merge -q --no-ff "req/REQ-$1-$2" -m "Merge req/REQ-$1-$2 into develop" -m "$2" -m "Refs: REQ-$1"
  git push -q 2>/dev/null
  git branch -q -d "req/REQ-$1-$2"; git push -q origin --delete "req/REQ-$1-$2" 2>/dev/null
}
git checkout -q -b req/REQ-0001-add-greeting develop
git push -q -u origin req/REQ-0001-add-greeting 2>/dev/null
yes_ "pushing the empty req/ branch reserves it on the remote" git ls-remote --exit-code --heads origin req/REQ-0001-add-greeting
eq_ "id scan sees the reserved id in branch names" "$(git branch -a --list '*REQ-*' | grep -c 'REQ-0001')" "2"
git checkout -q develop; git branch -q -D req/REQ-0001-add-greeting; git push -q origin --delete req/REQ-0001-add-greeting 2>/dev/null
newreq 0001 add-greeting feat
newreq 0002 add-farewell feat
eq_ "REQ-0001 is ready on develop" "$(status_of origin/develop:reqs/REQ-0001-20261007-add-greeting.md)" "ready"
eq_ "merge of the req/ branch is a real merge commit (2 parents)" "$(git rev-list --parents -n1 develop | wc -w)" "3"
no_ "req/ branch is gone locally and on the remote" git ls-remote --exit-code --heads origin 'req/REQ-0001-*'

sec "new-req: undo an unpublished merge with reset --hard HEAD^"
git checkout -q -b req/REQ-0009-tmp develop; mkreq 0009 tmp feat; git add -A 2>/dev/null; git commit -q -m "docs(reqs): add draft REQ-0009 tmp"
before=$(git rev-parse develop)
git checkout -q develop; git merge -q --no-ff req/REQ-0009-tmp -m "Merge req/REQ-0009-tmp into develop"
git reset -q --hard HEAD^
eq_ "develop is back at the commit before the merge" "$(git rev-parse develop)" "$before"
git branch -q -D req/REQ-0009-tmp

sec "leave the root checkout busy on a draft (req/REQ-0003)"
git checkout -q -b req/REQ-0003-draft-only develop
git push -q -u origin req/REQ-0003-draft-only 2>/dev/null
mkreq 0003 draft-only feat; git add -A 2>/dev/null; git commit -q -m "docs(reqs): add draft REQ-0003 draft-only"; git push -q 2>/dev/null
eq_ "root checkout is on the req/ branch" "$(git branch --show-current)" "req/REQ-0003-draft-only"

# ---------------------------------------------------------------- second machine
git clone -q "$S/remote.git" "$B" 2>/dev/null
( cd "$B" && git checkout -q develop )

# ---------------------------------------------------------------- claim
sec "check-req: claim by branch, while the root checkout is NOT on develop"
cd "$A"; git fetch -q --prune
WT1="$A/.claude/worktrees/feat-REQ-0001-add-greeting"
yes_ "worktree add --no-track -b from origin/develop works with root on req/ branch" \
  git worktree add -q --no-track -b feat/REQ-0001-add-greeting "$WT1" origin/develop
eq_ "root checkout branch did not change" "$(git branch --show-current)" "req/REQ-0003-draft-only"
no_ "--no-track: the new branch has no upstream yet" git -C "$WT1" rev-parse --abbrev-ref '@{u}'
no_ "a second local claim of the same branch fails" \
  git worktree add -q --no-track -b feat/REQ-0001-add-greeting "$A/.claude/worktrees/dup" origin/develop

sec "check-req: race between two machines"
( cd "$B" && git fetch -q && git worktree add -q --no-track -b feat/REQ-0001-add-greeting "$B/wt1" origin/develop ) 2>/dev/null
git -C "$WT1" push -q -u origin feat/REQ-0001-add-greeting 2>/dev/null
eq_ "after push -u the upstream is origin/<branch>" "$(git -C "$WT1" rev-parse --abbrev-ref '@{u}')" "origin/feat/REQ-0001-add-greeting"
yes_ "machine B sees the claim with ls-remote before it creates anything" \
  git -C "$B" ls-remote --exit-code --heads origin '*REQ-0001-*'
if git -C "$B/wt1" push -q -u origin feat/REQ-0001-add-greeting 2>/dev/null; then
  echo "  NOTE  B's push of the SAME commit is accepted (no-op): the branch push alone is not the lock"
else
  echo "  NOTE  B's push of the same commit was rejected"
fi
# A records the claim first
( cd "$WT1" && setstatus reqs/REQ-0001-20261007-add-greeting.md in-progress \
  && sed -i 's#^branch:.*#branch: feat/REQ-0001-add-greeting#' reqs/REQ-0001-20261007-add-greeting.md \
  && git commit -q -am "chore(reqs): claim REQ-0001" -m "Refs: REQ-0001" && git push -q 2>/dev/null )
( cd "$B/wt1" && setstatus reqs/REQ-0001-20261007-add-greeting.md in-progress \
  && git commit -q -am "chore(reqs): claim REQ-0001" -m "Refs: REQ-0001" )
no_ "B's claim commit is rejected by the remote: only one machine wins" git -C "$B/wt1" push -q
( cd "$B" && git worktree remove wt1 && git branch -q -D feat/REQ-0001-add-greeting )
no_ "B cleaned up its lost claim" git -C "$B" rev-parse --verify -q feat/REQ-0001-add-greeting

# ---------------------------------------------------------------- overview
sec "check-req: overview without checking anything out (root on req/ branch)"
cd "$A"; git fetch -q --prune
files=$(git ls-tree --name-only origin/develop reqs/ | grep 'REQ-' | tr '\n' ' ')
eq_ "ls-tree lists the approved requests on origin/develop" "$files" "reqs/REQ-0001-20261007-add-greeting.md reqs/REQ-0002-20261007-add-farewell.md "
eq_ "develop still says ready for the claimed request" "$(status_of origin/develop:reqs/REQ-0001-20261007-add-greeting.md)" "ready"
rb=$(git branch -a --list '*REQ-0001-*' --format='%(refname:short)' | grep -v '^req/' | grep -v '^origin/req/' | head -1)
eq_ "request branch found by id in the branch name" "$rb" "feat/REQ-0001-add-greeting"
eq_ "effective status comes from the request branch" "$(status_of "$rb:reqs/REQ-0001-20261007-add-greeting.md")" "in-progress"
eq_ "unclaimed request has no request branch" "$(git branch -a --list '*REQ-0002-*' --format='%(refname:short)' | grep -v 'req/' | wc -l | tr -d ' ')" "0"
eq_ "drafts are found as req/ branches" "$(git branch --list 'req/REQ-*' --format='%(refname:short)')" "req/REQ-0003-draft-only"
eq_ "draft title is readable from its branch" "$(git show req/REQ-0003-draft-only:reqs/REQ-0003-20261007-draft-only.md | sed -n 's/^title: //p')" "draft-only"

# ---------------------------------------------------------------- implement + hand over
sec "check-req: implement, mark for review, remove the worktree, keep the branch"
( cd "$WT1" && echo "greeting" >> src/app.txt && git commit -q -am "feat: add greeting" -m "Refs: REQ-0001" && git push -q 2>/dev/null \
  && setstatus reqs/REQ-0001-20261007-add-greeting.md review && git commit -q -am "chore(reqs): mark REQ-0001 for review" -m "Refs: REQ-0001" && git push -q 2>/dev/null )
eq_ "worktree is clean before removal" "$(git -C "$WT1" status --porcelain | wc -l | tr -d ' ')" "0"
eq_ "nothing unpushed before removal" "$(git -C "$WT1" log origin/feat/REQ-0001-add-greeting..HEAD --oneline | wc -l | tr -d ' ')" "0"
yes_ "git -C <root> worktree remove works from outside the worktree" git -C "$A" worktree remove "$WT1"
yes_ "the branch is kept" git rev-parse --verify -q feat/REQ-0001-add-greeting
[ -d "$WT1" ] && ng "worktree folder still exists" || ok "worktree folder is gone"

sec "check-req: removing a worktree while a shell sits inside it (Windows)"
WT2="$A/.claude/worktrees/feat-REQ-0002-add-farewell"
git worktree add -q --no-track -b feat/REQ-0002-add-farewell "$WT2" origin/develop
git -C "$WT2" push -q -u origin feat/REQ-0002-add-farewell 2>/dev/null
( cd "$WT2" && setstatus reqs/REQ-0002-20261007-add-farewell.md in-progress && git commit -q -am "chore(reqs): claim REQ-0002" -m "Refs: REQ-0002" \
  && echo "farewell" >> src/app.txt && git commit -q -am "feat: add farewell" -m "Refs: REQ-0002" && git push -q 2>/dev/null )
out=$( cd "$WT2" && git -C "$A" worktree remove "$WT2" 2>&1 ); rc=$?
echo "  NOTE  remove with cwd inside the worktree: exit=$rc ${out:+| $out}"
if [ -d "$WT2" ]; then echo "  NOTE  folder still present after that attempt"; else echo "  NOTE  folder removed even with cwd inside"; fi
git worktree prune
[ -d "$WT2" ] || git worktree add -q "$WT2" feat/REQ-0002-add-farewell

# ---------------------------------------------------------------- review
sec "review: check out the request branch in the root checkout"
cd "$A"
git checkout -q develop
no_ "checkout of a branch that a worktree still holds is refused" git checkout -q feat/REQ-0002-add-farewell
yes_ "checkout of the reviewed branch works once its worktree is gone" git checkout -q feat/REQ-0001-add-greeting
# check-req: resuming a request while the root checkout is still on its branch
no_ "worktree add is refused for the branch that the root checkout is on" git worktree add -q "$WT1" feat/REQ-0001-add-greeting
git checkout -q develop
yes_ "worktree add works once the root checkout is back on develop" git worktree add -q "$WT1" feat/REQ-0001-add-greeting
git worktree remove "$WT1"; git checkout -q feat/REQ-0001-add-greeting
# develop moves on meanwhile (another request merged elsewhere)
( cd "$B" && git pull -q --ff-only 2>/dev/null && echo "other" > src/other.txt && git add -A 2>/dev/null && git commit -q -m "feat: other work" && git push -q 2>/dev/null )
git fetch -q
eq_ "branch is behind develop by one commit" "$(git log HEAD..origin/develop --oneline | wc -l | tr -d ' ')" "1"
yes_ "merge origin/develop into the request branch" git merge -q origin/develop -m "Merge develop into feat/REQ-0001-add-greeting"
echo "fix" >> src/app.txt; git commit -q -am "fix: small fix found in verify" -m "Refs: REQ-0001"
sed -i 's/- \[ \] criterion one/- [x] criterion one/' reqs/REQ-0001-20261007-add-greeting.md
git commit -q -am "docs(reqs): record review result of REQ-0001" -m "Refs: REQ-0001"; git push -q 2>/dev/null
( cd "$B" && git fetch -q --prune && git checkout -q feat/REQ-0001-add-greeting 2>/dev/null )
eq_ "on another machine, checkout creates the branch from origin" "$(git -C "$B" rev-parse --abbrev-ref 'feat/REQ-0001-add-greeting@{u}' 2>/dev/null)" "origin/feat/REQ-0001-add-greeting"
( cd "$B" && git checkout -q develop && git branch -q -D feat/REQ-0001-add-greeting )

# ---------------------------------------------------------------- merge request
sec "merge: close on the branch, merge --no-ff into develop, delete the branch"
f=REQ-0001-20261007-add-greeting.md
setstatus "reqs/$f" done
git mv "reqs/$f" "reqs/done/$f"
git commit -q -am "chore(reqs): close REQ-0001" -m "Refs: REQ-0001"; git push -q 2>/dev/null
git checkout -q develop; git pull -q --ff-only 2>/dev/null
yes_ "merge --no-ff has no conflicts (branch already contains develop)" \
  git merge -q --no-ff feat/REQ-0001-add-greeting -m "Merge feat/REQ-0001-add-greeting into develop" -m "add-greeting" -m "Refs: REQ-0001"
git push -q 2>/dev/null
eq_ "merge commit message has subject, title and Refs" "$(git log -1 --format=%B | sed '/^$/d' | tr '\n' '|')" "Merge feat/REQ-0001-add-greeting into develop|add-greeting|Refs: REQ-0001|"
eq_ "develop has the request only in reqs/done, as done" "$(status_of develop:reqs/done/$f)" "done"
no_ "the copy in reqs/ is gone on develop" git cat-file -e "develop:reqs/$f"
yes_ "is-ancestor confirms the merge" git merge-base --is-ancestor feat/REQ-0001-add-greeting origin/develop
yes_ "branch -d accepts the merged branch" git branch -q -d feat/REQ-0001-add-greeting
yes_ "remote branch deleted" git push -q origin --delete feat/REQ-0001-add-greeting

# ---------------------------------------------------------------- release
sec "release: first release v0.1.0"
no_ "no tag yet: git describe fails (skill must expect this)" git describe --tags --abbrev=0 master
git checkout -q -b release/v0.1.0 develop; git push -q -u origin release/v0.1.0 2>/dev/null
git checkout -q master; git pull -q --ff-only 2>/dev/null
git merge -q --no-ff release/v0.1.0 -m "Merge release/v0.1.0 into master" -m "Release v0.1.0"
eq_ "master equals the release tree" "$(git diff master release/v0.1.0 --stat | wc -l | tr -d ' ')" "0"
git tag -a v0.1.0 -m "Release v0.1.0"
git checkout -q develop
out=$(git merge --no-ff release/v0.1.0 -m "Merge release/v0.1.0 into develop" -m "Release v0.1.0" 2>&1)
echo "  NOTE  merging an unchanged release branch into develop says: $out"
yes_ "push --atomic of master, develop and the tag" git push -q --atomic origin master develop v0.1.0
yes_ "tag is on the remote" git ls-remote --exit-code --tags origin v0.1.0
eq_ "last tag found from master" "$(git describe --tags --abbrev=0 master)" "v0.1.0"
git branch -q -d release/v0.1.0; git push -q origin --delete release/v0.1.0 2>/dev/null

# ---------------------------------------------------------------- drop
sec "merge: drop REQ-0002 through a short-lived branch"
git worktree remove --force "$WT2" 2>/dev/null; git worktree prune
f2=REQ-0002-20261007-add-farewell.md
eq_ "commits that would be abandoned are listed" "$(git log develop..feat/REQ-0002-add-farewell --oneline | wc -l | tr -d ' ')" "2"
git checkout -q -b req/REQ-0002-drop develop
git show "feat/REQ-0002-add-farewell:reqs/$f2" > "reqs/$f2"
setstatus "reqs/$f2" done; echo "Dropped (2026-10-07): not needed" >> "reqs/$f2"
git mv "reqs/$f2" "reqs/done/$f2"; git commit -q -am "chore(reqs): drop REQ-0002" -m "Refs: REQ-0002"
git checkout -q develop
git merge -q --no-ff req/REQ-0002-drop -m "Merge req/REQ-0002-drop into develop" -m "Refs: REQ-0002"; git push -q 2>/dev/null
git branch -q -d req/REQ-0002-drop
eq_ "dropped request is done in reqs/done on develop" "$(status_of develop:reqs/done/$f2)" "done"
no_ "dropped request left no copy in reqs/" git cat-file -e "develop:reqs/$f2"
eq_ "the dropped request kept its notes from the request branch" "$(git show develop:reqs/done/$f2 | grep -c 'Dropped')" "1"
no_ "the dropped branch is NOT merged into develop" git merge-base --is-ancestor feat/REQ-0002-add-farewell develop
yes_ "FINDING: branch -d still deletes it, because it is pushed (so -d is no safety net)" git branch -d feat/REQ-0002-add-farewell
yes_ "the remote branch still holds the abandoned commits" git ls-remote --exit-code --heads origin feat/REQ-0002-add-farewell
git push -q origin --delete feat/REQ-0002-add-farewell 2>/dev/null

# ---------------------------------------------------------------- release 0.2.0 with bump
sec "release: v0.2.0 with a version bump on the release branch"
eq_ "requests closed since the last tag" "$(git diff --name-only --diff-filter=A v0.1.0..develop -- reqs/done/ | tr '\n' ' ')" "reqs/done/REQ-0002-20261007-add-farewell.md "
git checkout -q -b release/v0.2.0 develop
echo "0.2.0" > src/version.txt; git commit -q -am "chore(release): bump version to 0.2.0"
git checkout -q master; git merge -q --no-ff release/v0.2.0 -m "Merge release/v0.2.0 into master" -m "Release v0.2.0"
eq_ "master equals the release tree" "$(git diff master release/v0.2.0 --stat | wc -l | tr -d ' ')" "0"
git tag -a v0.2.0 -m "Release v0.2.0"
git checkout -q develop
yes_ "release with its own commit merges into develop with --no-ff" git merge -q --no-ff release/v0.2.0 -m "Merge release/v0.2.0 into develop" -m "Release v0.2.0"
git push -q --atomic origin master develop v0.2.0 2>/dev/null
git branch -q -d release/v0.2.0

# ---------------------------------------------------------------- hotfix
sec "hotfix: request on develop, branch from master, file copied by the claim"
newreq 0004 fix-crash hotfix
echo "next feature" > src/next.txt; git add -A 2>/dev/null; git commit -q -m "feat: next feature on develop"; git push -q 2>/dev/null
f4=REQ-0004-20261007-fix-crash.md
no_ "the request file is not on master" git cat-file -e "origin/master:reqs/$f4"
WTH="$A/.claude/worktrees/hotfix-v0.2.1"
yes_ "hotfix worktree from origin/master" git worktree add -q --no-track -b hotfix/v0.2.1 "$WTH" origin/master
( cd "$WTH" && git show "origin/develop:reqs/$f4" > "reqs/$f4" && setstatus "reqs/$f4" in-progress \
  && sed -i 's#^branch:.*#branch: hotfix/v0.2.1#' "reqs/$f4" && git add -A 2>/dev/null \
  && git commit -q -m "chore(reqs): claim REQ-0004" -m "Refs: REQ-0004" \
  && echo "crash fixed" >> src/app.txt && git commit -q -am "fix: crash" -m "Refs: REQ-0004" \
  && echo "0.2.1" > src/version.txt && git commit -q -am "chore(release): bump version to 0.2.1" \
  && setstatus "reqs/$f4" review && git commit -q -am "chore(reqs): mark REQ-0004 for review" -m "Refs: REQ-0004" \
  && git push -q -u origin hotfix/v0.2.1 2>/dev/null )
git worktree remove "$WTH"
hb=""
for b in $(git branch -a --list '*hotfix/*' --format='%(refname:short)'); do
  git ls-tree -r --name-only "$b" reqs/ | grep -q 'REQ-0004-' && hb="$b" && break
done
eq_ "overview finds the hotfix branch by the request file it carries" "$hb" "hotfix/v0.2.1"
eq_ "effective status of the hotfix request" "$(status_of "hotfix/v0.2.1:reqs/$f4")" "review"

sec "hotfix: an open release branch with a higher version (conflict case)"
git checkout -q -b release/v0.3.0 develop; echo "0.3.0" > src/version.txt; git commit -q -am "chore(release): bump version to 0.3.0"

sec "hotfix: close on the branch, merge into master, tag"
git checkout -q hotfix/v0.2.1
setstatus "reqs/$f4" done; git mv "reqs/$f4" "reqs/done/$f4"; git commit -q -am "chore(reqs): close REQ-0004" -m "Refs: REQ-0004"; git push -q 2>/dev/null
git checkout -q master; git pull -q --ff-only 2>/dev/null
yes_ "merge into master" git merge -q --no-ff hotfix/v0.2.1 -m "Merge hotfix/v0.2.1 into master" -m "Hotfix v0.2.1" -m "Refs: REQ-0004"
git tag -a v0.2.1 -m "Hotfix v0.2.1"
eq_ "master carries the closed request in reqs/done" "$(status_of master:reqs/done/$f4)" "done"

sec "hotfix: merge into develop with --no-commit and remove the stale copy"
git checkout -q develop
out=$(git merge --no-ff --no-commit hotfix/v0.2.1 2>&1); rc=$?
echo "  NOTE  merge --no-ff --no-commit into develop: exit=$rc"
eq_ "no conflict on develop (version changed only on the hotfix side)" "$(git diff --name-only --diff-filter=U | wc -l | tr -d ' ')" "0"
yes_ "stale ready copy is still in reqs/ before the fix-up" test -f "reqs/$f4"
yes_ "git rm of the stale copy works inside the open merge" git rm -q "reqs/$f4"
yes_ "merge commit can be created" git commit -q -m "Merge hotfix/v0.2.1 into develop" -m "Hotfix v0.2.1" -m "Refs: REQ-0004"
eq_ "develop has the request only in reqs/done, as done" "$(status_of develop:reqs/done/$f4)" "done"
no_ "no copy left in reqs/ on develop" git cat-file -e "develop:reqs/$f4"
eq_ "develop took the hotfix version" "$(git show develop:src/version.txt)" "0.2.1"
eq_ "develop kept its own work" "$(git show develop:src/next.txt)" "next feature"
eq_ "the merge commit has two parents" "$(git rev-list --parents -n1 develop | wc -w | tr -d ' ')" "3"

sec "hotfix: merge into the open release branch (version conflict expected)"
git checkout -q release/v0.3.0
git merge --no-ff --no-commit hotfix/v0.2.1 >/dev/null 2>&1
eq_ "conflict is exactly the version file" "$(git diff --name-only --diff-filter=U | tr '\n' ' ')" "src/version.txt "
echo "0.3.0" > src/version.txt; git add src/version.txt
[ -f "reqs/$f4" ] && git rm -q "reqs/$f4"
yes_ "resolved by keeping the higher version" git commit -q -m "Merge hotfix/v0.2.1 into release/v0.3.0" -m "Hotfix v0.2.1" -m "Refs: REQ-0004"
eq_ "release branch keeps 0.3.0" "$(git show release/v0.3.0:src/version.txt)" "0.3.0"

sec "hotfix: finish"
git checkout -q develop
yes_ "push --atomic master develop tag" git push -q --atomic origin master develop v0.2.1
yes_ "hotfix is an ancestor of master" git merge-base --is-ancestor hotfix/v0.2.1 master
yes_ "hotfix is an ancestor of develop" git merge-base --is-ancestor hotfix/v0.2.1 develop
yes_ "branch -d accepts the merged hotfix branch" git branch -q -d hotfix/v0.2.1
git push -q origin --delete hotfix/v0.2.1 2>/dev/null

sec "release after a hotfix: master must equal the release tree"
git checkout -q release/v0.3.0
git merge -q develop -m "Merge develop into release/v0.3.0" 2>/dev/null
eq_ "release branch still says 0.3.0 after taking develop" "$(cat src/version.txt)" "0.3.0"
git checkout -q master
yes_ "merge release into master" git merge -q --no-ff release/v0.3.0 -m "Merge release/v0.3.0 into master" -m "Release v0.3.0"
eq_ "master equals the release tree (hotfix was merged back)" "$(git diff master release/v0.3.0 --stat | wc -l | tr -d ' ')" "0"
git checkout -q develop

# ================================================================ no remote at all
C="$S/C"
sec "no remote: setup, and how a skill tells that there is none"
mkdir "$C"; cd "$C"; git init -q; initrepo; git checkout -q develop
eq_ "git remote lists nothing" "$(git remote | wc -l | tr -d ' ')" "0"
no_ "origin/develop does not exist, so develop itself is <develop-ref>" git rev-parse --verify -q origin/develop

sec "no remote: new-req reserves the id with the local branch alone"
git checkout -q -b req/REQ-0001-local-one develop
eq_ "id scan sees the reserved id in the local branch name" "$(git branch -a --list '*REQ-*' | grep -c 'REQ-0001')" "1"
no_ "a second session cannot create the same req/ branch" git branch req/REQ-0001-local-one develop
git checkout -q develop; git branch -q -D req/REQ-0001-local-one
localreq 0001 local-one feat
eq_ "the request is ready on the local develop" "$(status_of develop:reqs/REQ-0001-20261007-local-one.md)" "ready"
no_ "the merged req/ branch is gone" git rev-parse --verify -q req/REQ-0001-local-one

sec "no remote: the local branch is the claim"
WC="$C/.claude/worktrees/feat-REQ-0001-local-one"
yes_ "worktree add -b from the local develop" git worktree add -q --no-track -b feat/REQ-0001-local-one "$WC" develop
no_ "a second local claim of the same branch fails" \
  git worktree add -q --no-track -b feat/REQ-0001-local-one "$C/.claude/worktrees/dup" develop
( cd "$WC" && setstatus reqs/REQ-0001-20261007-local-one.md in-progress \
  && sed -i 's#^branch:.*#branch: feat/REQ-0001-local-one#' reqs/REQ-0001-20261007-local-one.md \
  && git commit -q -am "chore(reqs): claim REQ-0001" -m "Refs: REQ-0001" \
  && echo "local work" >> src/app.txt && git commit -q -am "feat: local work" -m "Refs: REQ-0001" \
  && setstatus reqs/REQ-0001-20261007-local-one.md review \
  && git commit -q -am "chore(reqs): mark REQ-0001 for review" -m "Refs: REQ-0001" )
eq_ "overview reads the effective status from the local branch" "$(status_of feat/REQ-0001-local-one:reqs/REQ-0001-20261007-local-one.md)" "review"

sec "no remote: remove the worktree without a push, the commits stay on the branch"
eq_ "worktree is clean before removal" "$(git -C "$WC" status --porcelain | wc -l | tr -d ' ')" "0"
eq_ "HEAD of the worktree is the tip of the local branch" "$(git -C "$WC" rev-parse HEAD)" "$(git rev-parse feat/REQ-0001-local-one)"
yes_ "worktree remove works" git -C "$C" worktree remove "$WC"
eq_ "the branch still holds the three commits" "$(git log develop..feat/REQ-0001-local-one --oneline | wc -l | tr -d ' ')" "3"

sec "no remote: review and merge on local branches only"
yes_ "checkout of the request branch in the root checkout" git checkout -q feat/REQ-0001-local-one
fc=REQ-0001-20261007-local-one.md
setstatus "reqs/$fc" done; git mv "reqs/$fc" "reqs/done/$fc"
git commit -q -am "chore(reqs): close REQ-0001" -m "Refs: REQ-0001"
git checkout -q develop
yes_ "merge --no-ff into the local develop" \
  git merge -q --no-ff feat/REQ-0001-local-one -m "Merge feat/REQ-0001-local-one into develop" -m "local-one" -m "Refs: REQ-0001"
yes_ "is-ancestor confirms the merge on the local develop" git merge-base --is-ancestor feat/REQ-0001-local-one develop
yes_ "branch -d accepts the merged branch" git branch -q -d feat/REQ-0001-local-one
eq_ "develop has the request only in reqs/done, as done" "$(status_of develop:reqs/done/$fc)" "done"

sec "no remote: branch -d protects an unmerged branch (unlike a pushed one)"
git checkout -q -b feat/REQ-0002-unmerged develop
echo "x" >> src/app.txt; git commit -q -am "feat: not merged"
git checkout -q develop
no_ "branch -d refuses a branch that is neither merged nor pushed" git branch -d feat/REQ-0002-unmerged
git branch -q -D feat/REQ-0002-unmerged

sec "no remote: release with a local tag"
git checkout -q -b release/v0.1.0 develop
git checkout -q master
yes_ "merge the release into the local master" git merge -q --no-ff release/v0.1.0 -m "Merge release/v0.1.0 into master" -m "Release v0.1.0"
git tag -a v0.1.0 -m "Release v0.1.0"
git checkout -q develop
git merge -q --no-ff release/v0.1.0 -m "Merge release/v0.1.0 into develop" -m "Release v0.1.0" >/dev/null 2>&1
eq_ "the local tag is the release" "$(git describe --tags --abbrev=0 master)" "v0.1.0"
yes_ "release branch is an ancestor of master and develop" sh -c 'git merge-base --is-ancestor release/v0.1.0 master && git merge-base --is-ancestor release/v0.1.0 develop'
git branch -q -d release/v0.1.0

# ================================================================ a remote, nothing pushed
D="$S/D"; D2="$S/D2"
sec "push-policy never: the local develop is ahead, so it is <develop-ref>"
cd "$S"; git init -q --bare remote-d.git
git clone -q remote-d.git D 2>/dev/null; cd "$D"; initrepo
git push -q -u origin master develop 2>/dev/null; git checkout -q develop
git clone -q "$S/remote-d.git" "$D2" 2>/dev/null; ( cd "$D2" && git checkout -q develop )
localreq 0001 not-pushed feat
git fetch -q --prune
eq_ "the local develop has commits that origin/develop lacks" "$(git log origin/develop..develop --oneline | wc -l | tr -d ' ')" "3"
eq_ "origin/develop has nothing that the local develop lacks" "$(git log develop..origin/develop --oneline | wc -l | tr -d ' ')" "0"
no_ "origin/develop does not show the request that was not pushed" git cat-file -e "origin/develop:reqs/REQ-0001-20261007-not-pushed.md"
yes_ "the local develop shows it" git cat-file -e "develop:reqs/REQ-0001-20261007-not-pushed.md"

sec "push-policy never: a claim that is not pushed holds on this machine only"
WD="$D/.claude/worktrees/feat-REQ-0001-not-pushed"
git worktree add -q --no-track -b feat/REQ-0001-not-pushed "$WD" develop
( cd "$WD" && setstatus reqs/REQ-0001-20261007-not-pushed.md in-progress \
  && git commit -q -am "chore(reqs): claim REQ-0001" -m "Refs: REQ-0001" )
no_ "the remote does not know the claim" git ls-remote --exit-code --heads origin 'feat/REQ-0001-*'
eq_ "the branch has no upstream, so the overview shows it as not on the remote" "$(git -C "$WD" rev-parse --abbrev-ref '@{u}' 2>/dev/null)" ""
git worktree remove "$WD"

sec "push-policy never: both sides moved, the skill must see both"
( cd "$D2" && echo "other" > src/other.txt && git add -A 2>/dev/null && git commit -q -m "feat: other machine" && git push -q 2>/dev/null )
git fetch -q
eq_ "origin/develop now has a commit that the local develop lacks" "$(git log develop..origin/develop --oneline | wc -l | tr -d ' ')" "1"
eq_ "and the local develop still has its own commits" "$(git log origin/develop..develop --oneline | wc -l | tr -d ' ')" "3"
yes_ "the developer's later push is rejected until develop is brought together" sh -c '! git push -q origin develop 2>/dev/null'
yes_ "git pull --no-rebase brings them together with a merge commit" git pull -q --no-rebase origin develop
yes_ "then the push is accepted" git push -q origin develop

# ================================================================ protected develop
E="$S/E"; E2="$S/E2"
sec "protected develop: the remote refuses the push of a local merge"
cd "$S"; git init -q --bare remote-e.git
git clone -q remote-e.git E 2>/dev/null; cd "$E"; initrepo
git push -q -u origin master develop 2>/dev/null; git checkout -q develop
git clone -q "$S/remote-e.git" "$E2" 2>/dev/null; ( cd "$E2" && git checkout -q develop )
cat > "$S/remote-e.git/hooks/pre-receive" <<'HOOK'
#!/bin/sh
while read old new ref; do
  if [ "$ref" = "refs/heads/develop" ] && [ -z "$ALLOW_DEVELOP" ]; then
    echo "develop is protected" >&2; exit 1
  fi
done
exit 0
HOOK
chmod +x "$S/remote-e.git/hooks/pre-receive"
git checkout -q -b feat/REQ-0001-protected develop
echo "protected work" >> src/app.txt; git commit -q -am "feat: protected work" -m "Refs: REQ-0001"
yes_ "the topic branch can be pushed" git push -q -u origin feat/REQ-0001-protected
git checkout -q develop
before=$(git rev-parse develop)
git merge -q --no-ff feat/REQ-0001-protected -m "Merge feat/REQ-0001-protected into develop"
no_ "the push to develop is refused" git push -q origin develop
eq_ "HEAD is the unpublished merge commit (2 parents)" "$(git rev-list --parents -n1 HEAD | wc -w | tr -d ' ')" "3"
git reset -q --hard HEAD^
eq_ "reset --hard HEAD^ puts develop back to the published commit" "$(git rev-parse develop)" "$before"
eq_ "develop equals origin/develop again" "$(git rev-parse develop)" "$(git rev-parse origin/develop)"
yes_ "the topic branch still holds the work" git rev-parse --verify -q feat/REQ-0001-protected
no_ "the branch is not merged yet: merge pending" git merge-base --is-ancestor feat/REQ-0001-protected origin/develop

sec "protected develop: someone merges on the remote, the next run finds it"
( cd "$E2" && git fetch -q && git merge -q --no-ff origin/feat/REQ-0001-protected -m "Merge feat/REQ-0001-protected into develop" \
  && ALLOW_DEVELOP=1 git push -q origin develop 2>/dev/null )
git fetch -q --prune
yes_ "is-ancestor against origin/develop finds the merge, without a merge request" git merge-base --is-ancestor feat/REQ-0001-protected origin/develop
yes_ "pull --ff-only brings the local develop up to date" git pull -q --ff-only
yes_ "branch -d accepts the branch after the remote merge" git branch -q -d feat/REQ-0001-protected
yes_ "the remote branch can be deleted" git push -q origin --delete feat/REQ-0001-protected

echo
echo "RESULT: $PASS passed, $FAIL failed"
cd /
if [ "$FAIL" -eq 0 ] && [ -z "$KEEP" ]; then
  rm -rf "$S"
else
  echo "sandbox kept: $S"
fi
[ "$FAIL" -eq 0 ]
