#!/usr/bin/env bash
# Runs the git command sequences that the ss-workflow skills prescribe, and checks
# that git behaves as the skill files say. It tests git, not the agent: it does not
# start Claude, and it does not cover gh / glab.
#
# Since 0.6.0 every repository is a workspace: the requests, the docs, and the agent
# files live in the workspace repository, and each project is a submodule under
# projects/<project>, with its own branches and tags. The script builds a throwaway sandbox
# in a temporary folder:
#
#   ws.git, SSLib.git, SSDisp.git   bare remotes of the workspace and two projects
#   A                               the root checkout of the workspace
#   B                               the workspace on a second machine
#   C                               a workspace without any remote, with a project
#                                   added from a local path that has no remote either
#   E                               a project whose remote refuses pushes to develop
#   L                               a repository in the layout of ss-workflow <= 0.5.0,
#                                   converted into a source repository + a workspace
#
# It never touches this repository.
#
# Usage:  bash tests/git-sequences.sh
#         KEEP=1 bash tests/git-sequences.sh    # keep the sandbox for inspection
#
# Run it again whenever a skill's git steps change. Lines marked NOTE record how git
# behaved where the skills only need to know the behavior, not to enforce it.
S="$(mktemp -d "${TMPDIR:-/tmp}/ss-workflow-git-XXXXXX")" || exit 1
cd "$S" || exit 1
# On Windows (Git Bash), use the path in the form that git prints: C:/...
S="$(pwd -W 2>/dev/null || pwd)"
echo "sandbox: $S"
# Line endings stay as they are, so that the checks can compare file contents. The
# sandbox remotes are folders, and git refuses folder URLs for submodules unless
# protocol.file.allow is "always". Real project remotes are https or ssh URLs.
export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=core.autocrlf GIT_CONFIG_VALUE_0=false \
  GIT_CONFIG_KEY_1=protocol.file.allow GIT_CONFIG_VALUE_1=always
PASS=0; FAIL=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
ng()   { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
yes_() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ng "$d"; fi; }
no_()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ng "$d"; else ok "$d"; fi; }
eq_()  { if [ "$2" = "$3" ]; then ok "$1"; else ng "$1 (got '$2', want '$3')"; fi; }
sec()  { echo; echo "== $1"; }
count() { wc -l | tr -d ' '; }
status_of() { git show "$1" 2>/dev/null | sed -n 's/^status: //p' | head -1; }
setstatus() { sed -i "s/^status: .*/status: $2/" "$1"; }
mkreq() { # id slug type projects
  cat > "reqs/REQ-$1-20261007-$2.md" <<EOF
---
id: REQ-$1
title: $2
status: draft
type: $3
projects: [$4]
priority: normal
branch:
project-branch:
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
seed_src() { # name [folder of the bare remote] -> bare remote with master + develop
  local dir="${2:-$S}"
  git init -q --bare "$dir/$1.git"
  git -C "$dir/$1.git" symbolic-ref HEAD refs/heads/master
  git clone -q "$dir/$1.git" "$S/seed-$1" 2>/dev/null
  ( cd "$S/seed-$1" && git checkout -q -b master && echo "0.1.0" > version.txt && echo "$1" > app.txt \
    && printf "bin/\n" > .gitignore && git add -A && git commit -q -m "chore: initial commit" \
    && git branch develop && git push -q -u origin master develop 2>/dev/null )
  rm -rf "$S/seed-$1"
}
# The projects of the workspace that the helpers below work on.
P_ALL="SSLib SSDisp"
start() { # root wt branch project-branch src-base projects... -> worktree on the existing request branch + one per project
  local root=$1 wt=$2 b=$3 pb=$4 sbase=$5 p; shift 5
  git -C "$root" worktree add -q "$wt" "$b" || return 1
  for p in $P_ALL; do
    if echo " $* " | grep -q " $p "; then
      git -C "$root/projects/$p" worktree add -q --no-track -b "$pb" "$wt/projects/$p" "$sbase" || return 1
    else
      git -C "$root/projects/$p" worktree add -q --detach "$wt/projects/$p" "$(git -C "$wt" rev-parse "HEAD:projects/$p")" || return 1
    fi
  done
}
rmwt() { # root wt -> the project worktrees first, then the workspace worktree
  local p
  for p in $P_ALL; do
    [ -e "$2/projects/$p/.git" ] || continue
    git -C "$1/projects/$p" worktree remove "$2/projects/$p" || return 1
    git -C "$2" restore "projects/$p" 2>/dev/null || mkdir -p "$2/projects/$p"
  done
  git -C "$1" worktree remove "$2"
}
newreq() { # id slug type projects -> the request approved (ready) on its branch, the root checkout back on develop
  local b="$3/REQ-$1-$2"
  git checkout -q -b "$b" develop
  mkreq "$1" "$2" "$3" "$4"
  git add -A 2>/dev/null; git commit -q -m "docs(reqs): add draft REQ-$1 $2" -m "Refs: REQ-$1"
  git push -q -u origin "$b" 2>/dev/null
  setstatus "reqs/REQ-$1-20261007-$2.md" ready
  git commit -q -am "docs(reqs): approve REQ-$1" -m "Refs: REQ-$1"; git push -q 2>/dev/null
  git checkout -q develop
}
startcommit() { # worktree file branch project-branch -> the start commit on the request branch
  ( cd "$1" && setstatus "reqs/$2" in-progress \
    && sed -i "s#^branch:.*#branch: $3#; s#^project-branch:.*#project-branch: $4#" "reqs/$2" \
    && git commit -q -am "chore(reqs): start ${2%%-2026*}" -m "Refs: ${2%%-2026*}" )
}
no_ws_info() { # project-folder -> true when no branch, tag, or commit message of the project names the workspace
  ! { git -C "$1" for-each-ref --format='%(refname)' refs/heads refs/remotes refs/tags; git -C "$1" log --all --format=%B; } \
    | grep -q 'REQ-\|-workspace\|Refs:'
}
pbranch_of() { # ref:path-of-request-file -> its project-branch
  git show "$1" 2>/dev/null | sed -n 's/^project-branch: *//p' | head -1
}
ws_master_merge() { # tag message -> merge develop into the workspace master, gitlinks = each project's master
  local p
  git checkout -q master; git pull -q --ff-only 2>/dev/null
  git merge -q --no-ff --no-commit develop >/dev/null 2>&1
  for p in $P_ALL; do
    git -C "projects/$p" fetch -q 2>/dev/null
    git update-index --cacheinfo "160000,$(git -C "projects/$p" rev-parse origin/master),projects/$p"
  done
  git commit -q -m "Merge develop into master" -m "$2"
  git tag -a "$1" -m "$2"
}

A="$S/A"; B="$S/B"

# ================================================================ init
sec "init: two projects, each with master + develop on its own remote"
seed_src SSLib; seed_src SSDisp
git init -q --bare ws.git; git -C ws.git symbolic-ref HEAD refs/heads/master
git clone -q ws.git A 2>/dev/null; cd "$A"; git checkout -q -b master
mkdir -p reqs/done docs; touch reqs/done/.gitkeep
echo "ss-workflow-version: 0.6.0" > AGENTS.md
printf ".claude/worktrees/\n" > .gitignore
yes_ "submodule add from the project's remote URL" git submodule add -q "$S/SSLib.git" projects/SSLib
git submodule add -q "$S/SSDisp.git" projects/SSDisp
eq_ ".gitmodules records the URL that it was given" "$(git config -f .gitmodules submodule.projects/SSDisp.url)" "$S/SSDisp.git"
eq_ "the submodule starts on its remote's default branch" "$(git -C projects/SSDisp rev-parse HEAD)" "$(git -C projects/SSDisp rev-parse origin/master)"
git add -A 2>/dev/null; git commit -q -m "chore: add ss-workflow workspace"
git branch develop; git checkout -q develop
for p in $P_ALL; do git -C "projects/$p" checkout -q --detach origin/develop; done
git add projects; git commit -q --allow-empty -m "chore(workspace): point the projects to develop"
git push -q -u origin master develop 2>/dev/null
eq_ "develop's gitlink is the project's develop" "$(git rev-parse develop:projects/SSDisp)" "$(git -C projects/SSDisp rev-parse origin/develop)"
eq_ "master's gitlink is the project's master" "$(git rev-parse master:projects/SSDisp)" "$(git -C projects/SSDisp rev-parse origin/master)"
eq_ "the root checkout is clean, submodules included" "$(git status --porcelain | count)" "0"
git clone -q --recurse-submodules -b develop "$S/ws.git" "$B" 2>/dev/null
eq_ "a second machine gets the projects with --recurse-submodules" "$(git -C "$B/projects/SSDisp" rev-parse HEAD)" "$(git rev-parse develop:projects/SSDisp)"

sec "init: a project given as a local path"
mkdir "$S/local"; git clone -q "$S/SSLib.git" "$S/local/SSLib"
git init -q "$S/ws-local"
out=$(GIT_CONFIG_COUNT=1 git -C "$S/ws-local" submodule add -q "$S/local/SSLib" projects/SSLib 2>&1); rc=$?
if [ $rc -ne 0 ]; then echo "  NOTE  submodule add from a local path, git defaults: refused ($(echo "$out" | head -1))"; else echo "  NOTE  submodule add from a local path worked with git's defaults"; fi
rm -rf "$S/ws-local"; git init -q "$S/ws-local"; cd "$S/ws-local"
origin=$(git -C "$S/local/SSLib" remote get-url origin)
git clone -q "$S/local/SSLib" projects/SSLib && git -C projects/SSLib remote set-url origin "$origin"
yes_ "clone from the local path, then add it with the origin URL (repo added in place)" git submodule add -q "$origin" projects/SSLib
eq_ ".gitmodules records the origin URL, not the local path" "$(git config -f .gitmodules submodule.projects/SSLib.url)" "$origin"
yes_ "absorbgitdirs moves the project's git folder under .git/modules" git submodule absorbgitdirs
yes_ "the gitdir is now in .git/modules" test -d .git/modules/projects/SSLib
eq_ "the developer's local working copy did not change" "$(git -C "$S/local/SSLib" status --porcelain | count)" "0"
cd "$A"

# ================================================================ new-req
sec "new-req: the request branch carries the draft from the start"
newreq 0001 add-greeting feat "SSLib, SSDisp"
yes_ "the pushed request branch reserves the id on the workspace remote" git ls-remote --exit-code --heads origin feat/REQ-0001-add-greeting
newreq 0002 add-farewell feat "SSDisp"
eq_ "REQ-0001 is ready on its branch" "$(status_of origin/feat/REQ-0001-add-greeting:reqs/REQ-0001-20261007-add-greeting.md)" "ready"
eq_ "the request names its projects" "$(git show origin/feat/REQ-0001-add-greeting:reqs/REQ-0001-20261007-add-greeting.md | sed -n 's/^projects: //p')" "[SSLib, SSDisp]"
eq_ "develop has no request file before the merge" "$(git ls-tree --name-only origin/develop reqs/ | grep -c 'REQ-')" "0"
eq_ "after the approval, the root checkout is back on develop" "$(git branch --show-current)" "develop"
eq_ "no commit reached the source repositories" "$(git -C projects/SSDisp log origin/develop --oneline | count)" "1"

sec "new-req: a type change renames the draft branch; a discarded draft leaves nothing"
git checkout -q -b feat/REQ-0006-typo develop; mkreq 0006 typo feat SSDisp
git add -A 2>/dev/null; git commit -q -m "docs(reqs): add draft REQ-0006 typo"; git push -q -u origin feat/REQ-0006-typo 2>/dev/null
sed -i 's/^type: .*/type: fix/' reqs/REQ-0006-20261007-typo.md
yes_ "branch -m renames the draft branch to the new type" git branch -m fix/REQ-0006-typo
yes_ "push the new name and delete the old one" sh -c "git push -q -u origin fix/REQ-0006-typo && git push -q origin --delete feat/REQ-0006-typo"
eq_ "the remote has the new name only" "$(git ls-remote --heads origin '*REQ-0006-*' | sed 's#.*refs/heads/##')" "fix/REQ-0006-typo"
git checkout -q -- reqs; git checkout -q develop
yes_ "discard: delete the draft branch, locally and on the remote" sh -c "git branch -q -D fix/REQ-0006-typo && git push -q origin --delete fix/REQ-0006-typo"
eq_ "nothing of the discarded draft is left" "$(git branch -a --list '*REQ-0006-*' | count)$(git ls-tree -r --name-only develop reqs/ | grep -c 'REQ-0006')" "00"

sec "leave the root checkout busy on a draft (REQ-0003), with a discussion round not committed yet"
git checkout -q -b feat/REQ-0003-draft-only develop
mkreq 0003 draft-only feat SSDisp; git add -A 2>/dev/null; git commit -q -m "docs(reqs): add draft REQ-0003 draft-only"; git push -q -u origin feat/REQ-0003-draft-only 2>/dev/null
echo "- [ ] criterion two" >> reqs/REQ-0003-20261007-draft-only.md
eq_ "the round only changed the file in the working tree" "$(git status --porcelain)" " M reqs/REQ-0003-20261007-draft-only.md"

# ================================================================ start
sec "check-req: start the request on its branch, then a branch in each project of the request"
cd "$A"; git fetch -q --prune
for p in $P_ALL; do git -C "projects/$p" fetch -q; done
WT1="$A/.claude/worktrees/feat-REQ-0001-add-greeting"
PB1=feat/add-greeting
for p in $P_ALL; do
  no_ "the project branch name is free in $p, locally and on the remote" sh -c \
    "git -C 'projects/$p' rev-parse --verify -q 'refs/heads/$PB1' || git -C 'projects/$p' ls-remote --exit-code --heads origin '$PB1'"
done
no_ "a worktree cannot take the branch that the root checkout is on (new-req switches back first)" \
  git worktree add -q "$A/.claude/worktrees/busy" feat/REQ-0003-draft-only
yes_ "worktree add takes the existing request branch while the root is busy on another draft" \
  git worktree add -q "$WT1" feat/REQ-0001-add-greeting
eq_ "a new workspace worktree has empty project folders" "$(ls -A "$WT1/projects/SSDisp" | count)" "0"
yes_ "the start commit is a plain commit on the request branch" startcommit "$WT1" REQ-0001-20261007-add-greeting.md feat/REQ-0001-add-greeting "$PB1"
git -C "$WT1" push -q 2>/dev/null
( cd "$B" && git fetch -q )
eq_ "another machine sees that the request is started" "$(git -C "$B" show origin/feat/REQ-0001-add-greeting:reqs/REQ-0001-20261007-add-greeting.md | sed -n 's/^status: //p')" "in-progress"
yes_ "project worktree with the project branch, from the project's develop" \
  git -C "$A/projects/SSLib" worktree add -q --no-track -b "$PB1" "$WT1/projects/SSLib" origin/develop
git -C "$A/projects/SSDisp" worktree add -q --no-track -b "$PB1" "$WT1/projects/SSDisp" origin/develop
eq_ "the project folder is a worktree of the root checkout's submodule" "$(sed -n 's#.*\(/modules/projects/SSDisp/worktrees/\).*#\1#p' "$WT1/projects/SSDisp/.git")" "/modules/projects/SSDisp/worktrees/"
eq_ "the workspace worktree is clean right after the start" "$(git -C "$WT1" status --porcelain | count)" "0"
eq_ "inside a project worktree, the superproject is the workspace worktree" "$(git -C "$WT1/projects/SSDisp" rev-parse --show-superproject-working-tree)" "$WT1"
yes_ "the project branches are pushed" sh -c "git -C '$WT1/projects/SSLib' push -q -u origin $PB1 && git -C '$WT1/projects/SSDisp' push -q -u origin $PB1"
eq_ "the root checkout's branch did not change" "$(git branch --show-current)" "feat/REQ-0003-draft-only"

sec "check-req: a project that the request does not touch is checked out detached at its gitlink"
WT2="$A/.claude/worktrees/feat-REQ-0002-add-farewell"
# another developer's own workspace already pushed a branch with the same name to SSDisp
( cd "$B/projects/SSDisp" && git checkout -q -b feat/add-farewell origin/develop && git push -q -u origin feat/add-farewell 2>/dev/null )
git -C projects/SSDisp fetch -q
yes_ "the check finds that feat/add-farewell is taken in SSDisp" git -C projects/SSDisp ls-remote --exit-code --heads origin feat/add-farewell
PB2=feat/add-farewell-message
no_ "the other name is free" git -C projects/SSDisp ls-remote --exit-code --heads origin "$PB2"
yes_ "start REQ-0002 (SSDisp only) with the other name" start "$A" "$WT2" feat/REQ-0002-add-farewell "$PB2" origin/develop SSDisp
eq_ "SSLib is detached at the gitlink" "$(git -C "$WT2/projects/SSLib" rev-parse HEAD)" "$(git -C "$WT2" rev-parse HEAD:projects/SSLib)"
eq_ "SSLib has no branch in that worktree" "$(git -C "$WT2/projects/SSLib" branch --show-current)" ""
startcommit "$WT2" REQ-0002-20261007-add-farewell.md feat/REQ-0002-add-farewell "$PB2"; git -C "$WT2" push -q 2>/dev/null
git -C "$WT2/projects/SSDisp" push -q -u origin "$PB2" 2>/dev/null
eq_ "the other developer's branch is untouched" "$(git -C projects/SSDisp rev-parse origin/feat/add-farewell)" "$(git -C projects/SSDisp rev-parse origin/develop)"

# ================================================================ overview
sec "check-req: overview without checking anything out"
git fetch -q --prune
rbs=$(git branch -a --list '*REQ-*' --format='%(refname:short)' | sed 's#^origin/##' | sort -u | tr '\n' ' ')
eq_ "the request branches list every open request" "$rbs" "feat/REQ-0001-add-greeting feat/REQ-0002-add-farewell feat/REQ-0003-draft-only "
rb=feat/REQ-0001-add-greeting
eq_ "effective status from the workspace request branch" "$(status_of "$rb:reqs/REQ-0001-20261007-add-greeting.md")" "in-progress"
eq_ "the project branch is read from the request file on the workspace branch" "$(pbranch_of "$rb:reqs/REQ-0001-20261007-add-greeting.md")" "$PB1"
eq_ "the project branch is found on the project's remote" "$(git -C projects/SSLib ls-remote --heads origin "$PB1" | count)" "1"
eq_ "a draft is a request branch whose file says draft" "$(status_of origin/feat/REQ-0003-draft-only:reqs/REQ-0003-20261007-draft-only.md)" "draft"

# ================================================================ implement + hand over
sec "check-req: commit in the projects, record the gitlinks, hand over"
( cd "$WT1/projects/SSLib" && echo "greet()" >> app.txt && git commit -q -am "feat: add greet()" -m "Return a greeting for a name." && git push -q 2>/dev/null )
( cd "$WT1/projects/SSDisp" && echo "greeting" >> app.txt && git commit -q -am "feat: show greeting" -m "Show the greeting on the start screen." && git push -q 2>/dev/null )
eq_ "the workspace sees both projects as moved" "$(git -C "$WT1" status --porcelain | tr '\n' '|')" " M projects/SSDisp| M projects/SSLib|"
yes_ "diff --submodule=log shows the project commits" sh -c "git -C '$WT1' diff --submodule=log | grep -q 'feat: show greeting'"
eq_ "the project commit has no Refs: footer" "$(git -C "$WT1/projects/SSDisp" log -1 --format=%B | grep -c '^Refs:')" "0"
( cd "$WT1" && setstatus reqs/REQ-0001-20261007-add-greeting.md review && git add reqs projects/SSLib projects/SSDisp \
  && git commit -q -m "chore(reqs): mark REQ-0001 for review" -m "Refs: REQ-0001" && git push -q 2>/dev/null )
eq_ "the hand-over commit records the project branch tip" "$(git rev-parse feat/REQ-0001-add-greeting:projects/SSDisp)" "$(git -C projects/SSDisp rev-parse "$PB1")"
eq_ "nothing unpushed in the project before removal" "$(git -C "$WT1/projects/SSDisp" log "origin/$PB1..HEAD" --oneline | count)" "0"
no_ "the workspace worktree cannot be removed while it holds project worktrees" git worktree remove "$WT1"
yes_ "the project worktree is removed from the root checkout's submodule" git -C "$A/projects/SSLib" worktree remove "$WT1/projects/SSLib"
eq_ "removing it deletes the folder, which the workspace sees as a deleted gitlink" "$(git -C "$WT1" status --porcelain)" " D projects/SSLib"
yes_ "restore puts back the empty folder" git -C "$WT1" restore projects/SSLib
eq_ "the workspace worktree is clean again" "$(git -C "$WT1" status --porcelain | count)" "0"
git -C "$A/projects/SSDisp" worktree remove "$WT1/projects/SSDisp"; git -C "$WT1" restore projects/SSDisp
yes_ "then the workspace worktree is removed without --force" git worktree remove "$WT1"
yes_ "the project branch is kept in the root checkout's submodule" git -C projects/SSDisp rev-parse --verify -q "$PB1"
yes_ "the workspace branch is kept" git rev-parse --verify -q feat/REQ-0001-add-greeting

# ================================================================ review
sec "review: check out both layers in the root checkout"
no_ "the root checkout cannot leave a draft with an uncommitted round" git checkout -q develop
git commit -q -am "docs(reqs): update draft REQ-0003" -m "Refs: REQ-0003"; git push -q 2>/dev/null
yes_ "keep as draft: commit the round, then the root checkout is free" git checkout -q develop
yes_ "checkout of the workspace request branch" git checkout -q feat/REQ-0001-add-greeting
yes_ "submodule update puts each project at the gitlink of the branch" git submodule update -q
for p in SSLib SSDisp; do git -C "projects/$p" checkout -q "$PB1"; done
eq_ "the project is on its project branch" "$(git -C projects/SSDisp branch --show-current)" "$PB1"
eq_ "the root checkout is clean, submodules included" "$(git status --porcelain | count)" "0"
echo "tmp" > projects/SSDisp/tmp.txt
eq_ "an untracked file in a project shows in the workspace status" "$(git status --porcelain)" " M projects/SSDisp"
echo "  NOTE  --porcelain (v1) shows ' M' for new commits, changed files, and untracked files alike; 'git status -s' shows ' ?' and ' m'"
eq_ "short status tells untracked content apart" "$(git status -s)" " ? projects/SSDisp"
echo "edit" >> projects/SSDisp/app.txt
eq_ "short status: modified content" "$(git status -s)" " m projects/SSDisp"
eq_ "the project's HEAD still equals the gitlink: no new commit" "$(git -C projects/SSDisp rev-parse HEAD)" "$(git rev-parse :projects/SSDisp)"
eq_ "the project's own status names the files" "$(git -C projects/SSDisp status --porcelain | tr '\n' '|')" " M app.txt|?? tmp.txt|"
git -C projects/SSDisp checkout -q -- app.txt; rm projects/SSDisp/tmp.txt
# the project's develop moves on meanwhile (another request, or another team)
( cd "$B/projects/SSDisp" && git checkout -q develop 2>/dev/null && echo "other" > other.txt && git add -A && git commit -q -m "feat: other work" && git push -q 2>/dev/null )
git -C projects/SSDisp fetch -q
yes_ "merge the project's develop into the project branch" git -C projects/SSDisp merge -q origin/develop -m "Merge develop into $PB1"
echo "fix" >> projects/SSDisp/app.txt; git -C projects/SSDisp commit -q -am "fix: keep the greeting on one line"
git -C projects/SSDisp push -q 2>/dev/null
eq_ "the workspace sees the new project commits" "$(git status --porcelain)" " M projects/SSDisp"
sed -i 's/- \[ \] criterion one/- [x] criterion one/' reqs/REQ-0001-20261007-add-greeting.md
git add reqs projects/SSDisp; git commit -q -m "docs(reqs): record review result of REQ-0001" -m "Refs: REQ-0001"; git push -q 2>/dev/null
eq_ "the review commit records the reviewed project commit" "$(git rev-parse HEAD:projects/SSDisp)" "$(git -C projects/SSDisp rev-parse HEAD)"
git checkout -q develop; git submodule update -q
eq_ "back on develop, the projects are at develop's gitlinks" "$(git -C projects/SSDisp rev-parse HEAD)" "$(git rev-parse develop:projects/SSDisp)"
eq_ "and the root checkout is clean" "$(git status --porcelain | count)" "0"

# ================================================================ merge request
sec "merge: the projects first, then the workspace"
git checkout -q feat/REQ-0001-add-greeting; git submodule update -q
for p in SSLib SSDisp; do
  ( cd "projects/$p" && git checkout -q develop 2>/dev/null && git pull -q --ff-only 2>/dev/null \
    && git merge -q --no-ff "$PB1" -m "Merge $PB1 into develop" -m "Add a greeting to the start screen." \
    && git push -q origin develop 2>/dev/null )
done
yes_ "is-ancestor: SSDisp's branch is merged on its remote" git -C projects/SSDisp merge-base --is-ancestor "$PB1" origin/develop
no_ "while the workspace branch is not merged yet (a later run continues here)" git merge-base --is-ancestor feat/REQ-0001-add-greeting origin/develop
f=REQ-0001-20261007-add-greeting.md
MERGE_LIB=$(git -C projects/SSLib rev-parse --short origin/develop)
setstatus "reqs/$f" done
echo "Merged into develop (2026-10-07): SSLib $MERGE_LIB, SSDisp $(git -C projects/SSDisp rev-parse --short origin/develop)" >> "reqs/$f"
git mv "reqs/$f" "reqs/done/$f"
git add reqs projects/SSLib projects/SSDisp
git commit -q -m "chore(reqs): close REQ-0001" -m "Refs: REQ-0001"; git push -q 2>/dev/null
eq_ "the close commit points to the project's develop merge commit" "$(git rev-parse HEAD:projects/SSDisp)" "$(git -C projects/SSDisp rev-parse origin/develop)"
git checkout -q develop; git pull -q --ff-only 2>/dev/null
yes_ "merge --no-ff of the workspace branch into develop" \
  git merge -q --no-ff feat/REQ-0001-add-greeting -m "Merge feat/REQ-0001-add-greeting into develop" -m "add-greeting" -m "Refs: REQ-0001"
git push -q 2>/dev/null; git submodule update -q
eq_ "develop's gitlink is the project's develop" "$(git rev-parse develop:projects/SSDisp)" "$(git -C projects/SSDisp rev-parse origin/develop)"
eq_ "develop has the request only in reqs/done, as done" "$(status_of develop:reqs/done/$f)" "done"
eq_ "the source history has no request commits" "$(git -C projects/SSDisp log origin/develop --format=%s | grep -c 'reqs')" "0"
for p in SSLib SSDisp; do
  yes_ "no branch, tag, or commit message of $p names the workspace or a request" no_ws_info "projects/$p"
done
yes_ "the project branches are deleted after the merge is confirmed" sh -c \
  "git -C projects/SSLib branch -q -d $PB1 && git -C projects/SSDisp branch -q -d $PB1 \
   && git -C projects/SSLib push -q origin --delete $PB1 && git -C projects/SSDisp push -q origin --delete $PB1"
yes_ "the workspace branch too" sh -c "git branch -q -d feat/REQ-0001-add-greeting && git push -q origin --delete feat/REQ-0001-add-greeting"
eq_ "the root checkout is clean" "$(git status --porcelain | count)" "0"

# ================================================================ gitlink behind
sec "check-req: a project's develop moved outside the workspace"
( cd "$B/projects/SSLib" && git checkout -q develop 2>/dev/null && git pull -q --ff-only 2>/dev/null \
  && echo "outside" > outside.txt && git add -A && git commit -q -m "feat: change made outside the workspace" && git push -q 2>/dev/null )
git -C projects/SSLib fetch -q
eq_ "rev-list counts the commits that develop's gitlink lacks" "$(git -C projects/SSLib rev-list --count "$(git rev-parse develop:projects/SSLib)..origin/develop")" "1"
git -C projects/SSLib checkout -q --detach origin/develop; git add projects/SSLib
git commit -q -m "chore(workspace): update SSLib to $(git -C projects/SSLib rev-parse --short HEAD)"; git push -q 2>/dev/null
eq_ "after the update, nothing is behind" "$(git -C projects/SSLib rev-list --count "$(git rev-parse develop:projects/SSLib)..origin/develop")" "0"

# ================================================================ workspace files only
sec "a request with projects: [] changes workspace files only"
newreq 0005 lib-spec docs ""
eq_ "the request names no project" "$(git show origin/docs/REQ-0005-lib-spec:reqs/REQ-0005-20261007-lib-spec.md | sed -n 's/^projects: //p')" "[]"
WT4="$A/.claude/worktrees/docs-REQ-0005-lib-spec"
links_before="$(git rev-parse develop:projects/SSLib) $(git rev-parse develop:projects/SSDisp)"
yes_ "the start takes the workspace branch; every project is detached" start "$A" "$WT4" docs/REQ-0005-lib-spec "" origin/develop
eq_ "no project got a branch" "$(git -C projects/SSLib branch -a --list '*lib-spec*' | count)$(git -C projects/SSDisp branch -a --list '*lib-spec*' | count)" "00"
( cd "$WT4" && setstatus reqs/REQ-0005-20261007-lib-spec.md in-progress \
  && git commit -q -am "chore(reqs): start REQ-0005" -m "Refs: REQ-0005" && git push -q 2>/dev/null \
  && mkdir -p docs/SSLib && echo "greet() returns a greeting" > docs/SSLib/spec.md && git add docs \
  && git commit -q -m "docs(SSLib): describe greet()" -m "Refs: REQ-0005" && git push -q 2>/dev/null \
  && setstatus reqs/REQ-0005-20261007-lib-spec.md review && git add reqs \
  && git commit -q -m "chore(reqs): mark REQ-0005 for review" -m "Refs: REQ-0005" && git push -q 2>/dev/null )
eq_ "the workspace diff without the request file is the docs change" "$(git diff --name-only origin/develop...docs/REQ-0005-lib-spec -- . ':!reqs' | tr '\n' ' ')" "docs/SSLib/spec.md "
eq_ "the detached projects leave the workspace worktree clean" "$(git -C "$WT4" status --porcelain | count)" "0"
yes_ "the worktrees are removed in the usual order" rmwt "$A" "$WT4"
git checkout -q docs/REQ-0005-lib-spec; git submodule update -q
f=REQ-0005-20261007-lib-spec.md; setstatus "reqs/$f" done; git mv "reqs/$f" "reqs/done/$f"; git add reqs
git commit -q -m "chore(reqs): close REQ-0005" -m "Refs: REQ-0005"; git push -q 2>/dev/null
git checkout -q develop; git pull -q --ff-only 2>/dev/null
yes_ "the workspace branch merges into develop with no project step" \
  git merge -q --no-ff docs/REQ-0005-lib-spec -m "Merge docs/REQ-0005-lib-spec into develop" -m "lib-spec" -m "Refs: REQ-0005"
git push -q 2>/dev/null; git submodule update -q
eq_ "develop has the spec" "$(git show develop:docs/SSLib/spec.md)" "greet() returns a greeting"
eq_ "and its gitlinks did not move" "$(git rev-parse develop:projects/SSLib) $(git rev-parse develop:projects/SSDisp)" "$links_before"
yes_ "the workspace branch is deleted after the merge is confirmed" sh -c "git merge-base --is-ancestor docs/REQ-0005-lib-spec origin/develop && git branch -q -d docs/REQ-0005-lib-spec && git push -q origin --delete docs/REQ-0005-lib-spec"
eq_ "the root checkout is clean" "$(git status --porcelain | count)" "0"

# ================================================================ release
sec "release: SSDisp v0.1.0 in its own repository"
git -C projects/SSDisp fetch -q --tags
no_ "no tag yet: describe fails (the skill must expect this)" git -C projects/SSDisp describe --tags --abbrev=0 origin/master
( cd projects/SSDisp && git checkout -q develop && git pull -q --ff-only 2>/dev/null && git checkout -q -b release/v0.1.0 \
  && git checkout -q master && git pull -q --ff-only 2>/dev/null \
  && git merge -q --no-ff release/v0.1.0 -m "Merge release/v0.1.0 into master" -m "Release v0.1.0" \
  && git tag -a v0.1.0 -m "Release v0.1.0" && git checkout -q develop \
  && git merge -q --no-ff release/v0.1.0 -m "Merge release/v0.1.0 into develop" -m "Release v0.1.0" >/dev/null 2>&1; \
  git push -q --atomic origin master develop v0.1.0 2>/dev/null && git branch -q -d release/v0.1.0 )
yes_ "the project tag is on the project's remote" git -C projects/SSDisp ls-remote --exit-code --tags origin v0.1.0
eq_ "SSLib got no tag: it was not released" "$(git -C projects/SSLib tag -l | count)" "0"

sec "release: the workspace records SSDisp v0.1.0"
git -C projects/SSDisp checkout -q --detach origin/develop; git add projects/SSDisp
eq_ "a release without commits of its own leaves the project's develop, so develop's gitlink, unchanged" "$(git diff --cached --name-only | count)" "0"
git diff --cached --quiet || git commit -q -m "chore(release): update SSDisp to v0.1.0"
yes_ "develop is merged into the workspace master with every gitlink at its project's master" ws_master_merge SSDisp/v0.1.0 "Release SSDisp v0.1.0"
eq_ "master's SSDisp is the released commit" "$(git rev-parse master:projects/SSDisp)" "$(git -C projects/SSDisp rev-parse 'v0.1.0^{commit}')"
eq_ "master's SSLib is SSLib's master (unreleased)" "$(git rev-parse master:projects/SSLib)" "$(git -C projects/SSLib rev-parse origin/master)"
eq_ "master has the request records of develop" "$(status_of master:reqs/done/REQ-0001-20261007-add-greeting.md)" "done"
git checkout -q develop; git submodule update -q
yes_ "push --atomic of the workspace master, develop and the tag" git push -q --atomic origin master develop SSDisp/v0.1.0
eq_ "the last workspace tag of SSDisp" "$(git describe --tags --abbrev=0 --match 'SSDisp/v*' master)" "SSDisp/v0.1.0"
eq_ "requests closed since the last SSDisp tag (none yet)" "$(git diff --name-only --diff-filter=A SSDisp/v0.1.0..develop -- reqs/done/ | count)" "0"
eq_ "the root checkout is clean" "$(git status --porcelain | count)" "0"

sec "release: changes made outside this workspace are found through the requests"
git -C projects/SSLib fetch -q
rec=$(git show develop:reqs/done/REQ-0001-20261007-add-greeting.md | sed -n 's/^Merged into develop.*SSLib \([0-9a-f]*\),.*/\1/p')
eq_ "the closed request records the project merge commit" "$(git -C projects/SSLib log -1 --format=%s "$rec")" "Merge feat/add-greeting into develop"
outside=$(git -C projects/SSLib log --first-parent --format='%H %s' origin/develop | grep -v "^$(git -C projects/SSLib rev-parse "$rec") " | cut -d' ' -f2- | tr '\n' '|')
eq_ "the first-parent line without the request's merge is the outside work" "$outside" "feat: change made outside the workspace|chore: initial commit|"

sec "release: SSLib v0.1.0 later; the master merge resolves the gitlinks"
( cd projects/SSLib && git checkout -q develop && git pull -q --ff-only 2>/dev/null && git checkout -q -b release/v0.1.0 \
  && echo "0.1.0-lib" > version.txt && git commit -q -am "chore(release): bump version to 0.1.0" \
  && git checkout -q master && git pull -q --ff-only 2>/dev/null \
  && git merge -q --no-ff release/v0.1.0 -m "Merge release/v0.1.0 into master" -m "Release v0.1.0" \
  && git tag -a v0.1.0 -m "Release v0.1.0" && git checkout -q develop \
  && git merge -q --no-ff release/v0.1.0 -m "Merge release/v0.1.0 into develop" -m "Release v0.1.0" \
  && git push -q --atomic origin master develop v0.1.0 2>/dev/null && git branch -q -d release/v0.1.0 )
git -C projects/SSLib checkout -q --detach origin/develop; git add projects/SSLib
git commit -q -m "chore(release): update SSLib to v0.1.0"
git checkout -q master; git pull -q --ff-only 2>/dev/null
out=$(git merge --no-ff --no-commit develop 2>&1); rc=$?
echo "  NOTE  merge --no-commit of develop into the workspace master: exit=$rc"
for p in $P_ALL; do git -C "projects/$p" fetch -q; git update-index --cacheinfo "160000,$(git -C "projects/$p" rev-parse origin/master),projects/$p"; done
eq_ "update-index --cacheinfo leaves no unmerged path" "$(git diff --name-only --diff-filter=U | count)" "0"
yes_ "the merge commit can be created" git commit -q -m "Merge develop into master" -m "Release SSLib v0.1.0"
git tag -a SSLib/v0.1.0 -m "Release SSLib v0.1.0"
eq_ "master's SSLib is the released commit" "$(git rev-parse master:projects/SSLib)" "$(git -C projects/SSLib rev-parse 'v0.1.0^{commit}')"
eq_ "master's SSDisp stays at its release" "$(git rev-parse master:projects/SSDisp)" "$(git -C projects/SSDisp rev-parse 'v0.1.0^{commit}')"
git checkout -q develop; git submodule update -q
git push -q --atomic origin master develop SSLib/v0.1.0 2>/dev/null
eq_ "SSLib's last workspace tag ignores SSDisp's" "$(git describe --tags --abbrev=0 --match 'SSLib/v*' master)" "SSLib/v0.1.0"
eq_ "requests closed since SSLib/v0.1.0" "$(git diff --name-only --diff-filter=A SSLib/v0.1.0..develop -- reqs/done/ | count)" "0"
eq_ "requests closed since the first tag of SSDisp... none, REQ-0001 was before it" "$(git diff --name-only --diff-filter=A SSDisp/v0.1.0..develop -- reqs/done/ | count)" "0"

# ================================================================ hotfix
sec "hotfix: SSDisp v0.1.1 from the masters of both layers"
rmwt "$A" "$WT2" 2>/dev/null
newreq 0004 fix-crash hotfix SSDisp
f4=REQ-0004-20261007-fix-crash.md
no_ "the request file is not on the workspace master" git cat-file -e "origin/master:reqs/$f4"
git fetch -q; for p in $P_ALL; do git -C "projects/$p" fetch -q; done
WTH="$A/.claude/worktrees/hotfix-SSDisp-v0.1.1"
git -C "$A" worktree add -q --no-track -b hotfix/SSDisp-v0.1.1 "$WTH" origin/master
git -C "$A/projects/SSDisp" worktree add -q --no-track -b hotfix/v0.1.1 "$WTH/projects/SSDisp" origin/master
git -C "$A/projects/SSLib" worktree add -q --detach "$WTH/projects/SSLib" "$(git -C "$WTH" rev-parse HEAD:projects/SSLib)"
eq_ "the hotfix starts from the released SSDisp" "$(git -C "$WTH/projects/SSDisp" rev-parse HEAD)" "$(git -C projects/SSDisp rev-parse 'v0.1.0^{commit}')"
eq_ "and from the released SSLib" "$(git -C "$WTH/projects/SSLib" rev-parse HEAD)" "$(git -C projects/SSLib rev-parse 'v0.1.0^{commit}')"
( cd "$WTH" && git show "hotfix/REQ-0004-fix-crash:reqs/$f4" > "reqs/$f4" && setstatus "reqs/$f4" in-progress \
  && sed -i 's#^branch:.*#branch: hotfix/SSDisp-v0.1.1#; s#^project-branch:.*#project-branch: hotfix/v0.1.1#' "reqs/$f4" && git add -A reqs \
  && git commit -q -m "chore(reqs): start REQ-0004" -m "Refs: REQ-0004" && git push -q -u origin hotfix/SSDisp-v0.1.1 2>/dev/null )
eq_ "the start commit copied the approved request from its draft branch" "$(status_of "hotfix/SSDisp-v0.1.1:reqs/$f4")" "in-progress"
yes_ "then the draft branch is deleted" sh -c "git branch -q -D hotfix/REQ-0004-fix-crash && git push -q origin --delete hotfix/REQ-0004-fix-crash"
eq_ "the hotfix request is on one branch only" "$(git branch -a --list '*REQ-0004*' | count)" "0"
( cd "$WTH/projects/SSDisp" && echo "crash fixed" >> app.txt && git commit -q -am "fix: crash on an empty greeting" \
  && echo "0.1.1" > version.txt && git commit -q -am "chore(release): bump version to 0.1.1" && git push -q -u origin hotfix/v0.1.1 2>/dev/null )
( cd "$WTH" && setstatus "reqs/$f4" review && git add reqs projects/SSDisp && git commit -q -m "chore(reqs): mark REQ-0004 for review" -m "Refs: REQ-0004" && git push -q 2>/dev/null )
yes_ "the hotfix worktrees are removed, projects first" rmwt "$A" "$WTH"

sec "hotfix: merge the project, then the workspace into master and develop"
( cd projects/SSDisp && git checkout -q master && git pull -q --ff-only 2>/dev/null \
  && git merge -q --no-ff hotfix/v0.1.1 -m "Merge hotfix/v0.1.1 into master" -m "Hotfix v0.1.1" \
  && git tag -a v0.1.1 -m "Hotfix v0.1.1" && git checkout -q develop && git pull -q --ff-only 2>/dev/null )
git -C projects/SSDisp merge -q --no-ff --no-commit hotfix/v0.1.1 >/dev/null 2>&1
eq_ "the project's develop takes the hotfix version (no conflict)" "$(git -C projects/SSDisp diff --name-only --diff-filter=U | count)" "0"
git -C projects/SSDisp commit -q -m "Merge hotfix/v0.1.1 into develop" -m "Hotfix v0.1.1"
yes_ "push --atomic of the project's master, develop and tag" git -C projects/SSDisp push -q --atomic origin master develop v0.1.1
git checkout -q hotfix/SSDisp-v0.1.1
setstatus "reqs/$f4" done; git mv "reqs/$f4" "reqs/done/$f4"
git -C projects/SSDisp checkout -q --detach v0.1.1; git add reqs projects/SSDisp
git commit -q -m "chore(reqs): close REQ-0004" -m "Refs: REQ-0004"
git checkout -q master; git pull -q --ff-only 2>/dev/null
yes_ "merge the workspace hotfix branch into the workspace master" git merge -q --no-ff hotfix/SSDisp-v0.1.1 -m "Merge hotfix/SSDisp-v0.1.1 into master" -m "Hotfix SSDisp v0.1.1" -m "Refs: REQ-0004"
git tag -a SSDisp/v0.1.1 -m "Hotfix SSDisp v0.1.1"
eq_ "the workspace master points to the hotfix release" "$(git rev-parse master:projects/SSDisp)" "$(git -C projects/SSDisp rev-parse 'v0.1.1^{commit}')"
git checkout -q develop
git merge --no-ff --no-commit hotfix/SSDisp-v0.1.1 >/dev/null 2>&1
echo "  NOTE  unmerged paths when the workspace hotfix branch meets develop: $(git diff --name-only --diff-filter=U | tr '\n' ' ')"
no_ "develop has no old copy of the hotfix request" git cat-file -e "HEAD:reqs/$f4"
git update-index --cacheinfo "160000,$(git -C projects/SSDisp rev-parse origin/develop),projects/SSDisp"
eq_ "no unmerged path after the stale copy and the gitlink are fixed" "$(git diff --name-only --diff-filter=U | count)" "0"
yes_ "the merge commit into develop" git commit -q -m "Merge hotfix/SSDisp-v0.1.1 into develop" -m "Hotfix SSDisp v0.1.1" -m "Refs: REQ-0004"
git submodule update -q
eq_ "develop's gitlink is the project's develop, which has the hotfix" "$(git rev-parse develop:projects/SSDisp)" "$(git -C projects/SSDisp rev-parse origin/develop)"
yes_ "the project's develop contains the hotfix" git -C projects/SSDisp merge-base --is-ancestor hotfix/v0.1.1 origin/develop
eq_ "develop has the request only in reqs/done" "$(status_of develop:reqs/done/$f4)" "done"
no_ "no stale copy in reqs/ on develop" git cat-file -e "develop:reqs/$f4"
yes_ "push --atomic of the workspace master, develop and the tag" git push -q --atomic origin master develop SSDisp/v0.1.1
yes_ "the hotfix left no workspace information in SSDisp" no_ws_info projects/SSDisp
eq_ "the root checkout is clean" "$(git status --porcelain | count)" "0"

# ================================================================ no remote at all
C="$S/C"
sec "no remote: a workspace and a project from a local path, neither has a remote"
mkdir -p "$S/localc"; git init -q "$S/localc/Tool"
( cd "$S/localc/Tool" && git checkout -q -b master && echo "0.1.0" > version.txt && git add -A && git commit -q -m "chore: initial commit" && git branch develop )
mkdir "$C"; cd "$C"; git init -q; git checkout -q -b master
mkdir -p reqs/done; touch reqs/done/.gitkeep; echo "ss-workflow-version: 0.6.0" > AGENTS.md; printf ".claude/worktrees/\n" > .gitignore
yes_ "submodule add of the local path (protocol.file.allow=always)" git -c protocol.file.allow=always submodule add -q "$S/localc/Tool" projects/Tool
eq_ ".gitmodules records the local path" "$(git config -f .gitmodules submodule.projects/Tool.url)" "$S/localc/Tool"
git add -A 2>/dev/null; git commit -q -m "chore: add ss-workflow workspace"; git branch develop; git checkout -q develop
eq_ "the workspace has no remote" "$(git remote | count)" "0"
eq_ "the project's origin is the developer's working copy" "$(git -C projects/Tool remote get-url origin)" "$S/localc/Tool"
git -C projects/Tool branch -q develop origin/develop
git -C projects/Tool commit -q --allow-empty -m "tmp"
no_ "pushing to the branch that the working copy has checked out is refused" git -C projects/Tool push -q origin HEAD:master
git -C projects/Tool checkout -q --detach HEAD^; git -C projects/Tool branch -q -f master origin/master
echo "  NOTE  so a project from a local path without a remote never pushes (push-policy: never for that project)"
P_ALL="Tool"
localreq() { # id slug -> ready on its local request branch
  git checkout -q -b "feat/REQ-$1-$2" develop; mkreq "$1" "$2" feat Tool
  git add -A 2>/dev/null; git commit -q -m "docs(reqs): add draft REQ-$1 $2"
  setstatus "reqs/REQ-$1-20261007-$2.md" ready; git commit -q -am "docs(reqs): approve REQ-$1"
  git checkout -q develop
}
localreq 0001 local-one
WC="$C/.claude/worktrees/feat-REQ-0001-local-one"
yes_ "start from the local branches of both layers" start "$C" "$WC" feat/REQ-0001-local-one feat/local-one develop Tool
no_ "a second worktree of the same request branch is refused" git worktree add -q "$C/.claude/worktrees/dup" feat/REQ-0001-local-one
( cd "$WC" && setstatus reqs/REQ-0001-20261007-local-one.md in-progress && git commit -q -am "chore(reqs): start REQ-0001" \
  && cd projects/Tool && echo "work" >> version.txt && git commit -q -am "feat: local work" \
  && cd ../.. && setstatus reqs/REQ-0001-20261007-local-one.md review && git add reqs projects/Tool && git commit -q -m "chore(reqs): mark REQ-0001 for review" )
yes_ "remove the worktrees without a push" rmwt "$C" "$WC"
eq_ "the project commit stays on the local project branch" "$(git -C projects/Tool log develop..feat/local-one --oneline | count)" "1"
git checkout -q feat/REQ-0001-local-one; git submodule update -q; git -C projects/Tool checkout -q feat/local-one
( cd projects/Tool && git checkout -q develop && git merge -q --no-ff feat/local-one -m "Merge feat/local-one into develop" -m "Do the local work." )
fc=REQ-0001-20261007-local-one.md
setstatus "reqs/$fc" done; git mv "reqs/$fc" "reqs/done/$fc"; git add reqs projects/Tool; git commit -q -m "chore(reqs): close REQ-0001"
git checkout -q develop
yes_ "merge --no-ff into the local workspace develop" git merge -q --no-ff feat/REQ-0001-local-one -m "Merge feat/REQ-0001-local-one into develop"
git submodule update -q
eq_ "develop's gitlink is the project's local develop" "$(git rev-parse develop:projects/Tool)" "$(git -C projects/Tool rev-parse develop)"
yes_ "no workspace information in the local project" no_ws_info projects/Tool
eq_ "the developer's working copy did not get the commit (nothing was pushed)" "$(git -C "$S/localc/Tool" log --oneline develop | count)" "1"
eq_ "the root checkout is clean" "$(git status --porcelain | count)" "0"
P_ALL="SSLib SSDisp"

# ================================================================ protected develop in a project
E="$S/E"
sec "protected project develop: the project merge is refused, the workspace waits"
seed_src Prot
cat > "$S/Prot.git/hooks/pre-receive" <<'HOOK'
#!/bin/sh
while read old new ref; do
  if [ "$ref" = "refs/heads/develop" ] && [ -z "$ALLOW_DEVELOP" ]; then echo "develop is protected" >&2; exit 1; fi
done
exit 0
HOOK
chmod +x "$S/Prot.git/hooks/pre-receive"
git init -q --bare "$S/ws-e.git"; git -C "$S/ws-e.git" symbolic-ref HEAD refs/heads/master
git clone -q "$S/ws-e.git" "$E" 2>/dev/null; cd "$E"; git checkout -q -b master
echo "ss-workflow-version: 0.6.0" > AGENTS.md; mkdir -p reqs/done; touch reqs/done/.gitkeep
git submodule add -q "$S/Prot.git" projects/Prot; git add -A 2>/dev/null; git commit -q -m "chore: add ss-workflow workspace"
git branch develop; git checkout -q develop; git push -q -u origin master develop 2>/dev/null
git checkout -q -b feat/REQ-0001-protected develop; git push -q -u origin feat/REQ-0001-protected 2>/dev/null
( cd projects/Prot && git checkout -q -b feat/protected origin/develop && echo "work" >> app.txt \
  && git commit -q -am "feat: protected work" && git push -q -u origin feat/protected 2>/dev/null )
git add projects/Prot; git commit -q -m "chore(reqs): mark REQ-0001 for review"; git push -q 2>/dev/null
( cd projects/Prot && git checkout -q develop 2>/dev/null && git merge -q --no-ff feat/protected -m "Merge feat/protected into develop" )
no_ "the push of the project's develop is refused" git -C projects/Prot push -q origin develop
git -C projects/Prot reset -q --hard HEAD^
eq_ "reset --hard HEAD^ puts the project's develop back" "$(git -C projects/Prot rev-parse develop)" "$(git -C projects/Prot rev-parse origin/develop)"
no_ "merge pending: the project branch is not merged" git -C projects/Prot merge-base --is-ancestor feat/protected origin/develop
no_ "and the workspace was not touched" git merge-base --is-ancestor feat/REQ-0001-protected origin/develop
( cd "$S" && git clone -q "$S/Prot.git" e2 2>/dev/null && cd e2 && git checkout -q develop \
  && git merge -q --no-ff origin/feat/protected -m "Merge feat/protected into develop" && ALLOW_DEVELOP=1 git push -q origin develop 2>/dev/null )
git -C projects/Prot fetch -q --prune
yes_ "the next run finds the remote merge with is-ancestor, and continues with the workspace" git -C projects/Prot merge-base --is-ancestor feat/protected origin/develop
git -C projects/Prot checkout -q --detach origin/develop; git add projects/Prot; git commit -q -m "chore(reqs): close REQ-0001"
git checkout -q develop; yes_ "the workspace merge" git merge -q --no-ff feat/REQ-0001-protected -m "Merge feat/REQ-0001-protected into develop"
eq_ "develop's gitlink is the remote merge commit" "$(git rev-parse develop:projects/Prot)" "$(git -C projects/Prot rev-parse origin/develop)"

# ================================================================ upgrade to 0.9.0: src/ becomes projects/
M="$S/M"
sec "upgrade 0.9.0: a workspace from before 0.9.0, with its projects in src/"
seed_src Mov
git init -q --bare "$S/ws-m.git"; git -C "$S/ws-m.git" symbolic-ref HEAD refs/heads/master
git clone -q "$S/ws-m.git" "$M" 2>/dev/null; cd "$M"; git checkout -q -b master
mkdir -p reqs/done src; touch reqs/done/.gitkeep
printf 'ss-workflow-version: 0.8.0\nprojects:\n  - name: Mov\n    path: src/Mov\n' > AGENTS.md
printf '# src/\n\n<!-- ss-workflow:managed id=src-rules -->\nrules\n<!-- /ss-workflow:managed -->\n\n## Project: Mov\n' > src/AGENTS.md
git submodule add -q "$S/Mov.git" src/Mov; git add -A 2>/dev/null; git commit -q -m "chore: add ss-workflow workspace"
git branch develop; git checkout -q develop
git -C src/Mov checkout -q --detach origin/develop; git add src/Mov; git commit -q --allow-empty -m "chore(workspace): point the projects to develop"
git push -q -u origin master develop 2>/dev/null
M3="$S/M3"; git clone -q --recurse-submodules -b develop "$S/ws-m.git" "$M3" 2>/dev/null
git checkout -q -b feat/REQ-0001-later develop; mkreq 0001 later feat Mov; setstatus reqs/REQ-0001-20261007-later.md ready
git add -A 2>/dev/null; git commit -q -m "docs(reqs): approve REQ-0001"; git push -q -u origin feat/REQ-0001-later 2>/dev/null; git checkout -q develop
P_ALL="Mov"

sec "upgrade 0.9.0: move the projects on develop and on the main branch"
movelayout() { # in the current folder: src/ -> projects/, the AGENTS.md paths, the block id
  no_ "git mv refuses a target folder that does not exist yet" git mv src/Mov projects/Mov
  mkdir -p projects
  git mv src/Mov projects/Mov && git mv src/AGENTS.md projects/AGENTS.md || return 1
  sed -i 's#^\(\s*path: \)src/#\1projects/#' AGENTS.md
  sed -i 's#^\# src/$#\# projects/#; s#id=src-rules#id=projects-rules#' projects/AGENTS.md
  git add AGENTS.md projects/AGENTS.md && git commit -q -m "chore(workspace): move the projects to projects/" && { rmdir src 2>/dev/null; true; }
}
yes_ "develop: move in the root checkout" movelayout
WMM="$M/.claude/worktrees/upgrade-master"
git worktree add -q "$WMM" master
eq_ "a temporary worktree of the main branch has the old layout, not populated" "$(ls -A "$WMM/src/Mov" | count)" "0"
if ( cd "$WMM" && movelayout >/dev/null ); then ok "the main branch: the same move in that worktree"; else ng "the main branch: the same move in that worktree"; fi
yes_ "the temporary worktree is removed" git worktree remove "$WMM"
eq_ "the main branch keeps its gitlink, now in projects/" "$(git rev-parse master:projects/Mov)" "$(git rev-parse master~1:src/Mov)"
git checkout -q develop; git submodule update -q
eq_ ".gitmodules has the new path; the submodule keeps its name" "$(git config -f .gitmodules submodule.src/Mov.path)" "projects/Mov"
eq_ "the gitlink moved with its commit" "$(git rev-parse develop:projects/Mov)" "$(git -C projects/Mov rev-parse origin/develop)"
eq_ "nothing is left in src/" "$(git ls-tree -r --name-only develop | grep -c '^src/')$(test -e src && echo 1 || echo 0)" "00"
eq_ "the project folder still works as a submodule" "$(git -C projects/Mov rev-parse --show-superproject-working-tree)" "$M"
eq_ "the root checkout is clean after the move" "$(git status --porcelain | count)" "0"
git push -q origin develop master 2>/dev/null
WM="$S/M2"; git clone -q --recurse-submodules -b develop "$S/ws-m.git" "$WM" 2>/dev/null
eq_ "a fresh clone gets the project in projects/" "$(git -C "$WM/projects/Mov" rev-parse HEAD)" "$(git rev-parse develop:projects/Mov)"

( cd "$M3" && git pull -q --ff-only 2>/dev/null; git submodule update -q 2>/dev/null )
eq_ "a clone from before the move: after pull and submodule update, the project is in projects/" "$(git -C "$M3/projects/Mov" rev-parse HEAD 2>/dev/null)" "$(git rev-parse develop:projects/Mov)"
echo "  NOTE  that clone keeps the old folder: src/Mov $(test -e "$M3/src/Mov/.git" && echo 'still has its .git file' || echo 'is gone'); status: '$(git -C "$M3" status --porcelain | tr '\n' ' ')'"
yes_ "the old folder can be deleted; the clone is clean afterwards" sh -c "rm -rf '$M3/src' && test -z \"\$(git -C '$M3' status --porcelain)\""
yes_ "and the project still works from projects/" git -C "$M3/projects/Mov" status

sec "upgrade 0.9.0: open request branches take the new layout before they start"
eq_ "a request branch from before the move still has src/" "$(git ls-tree --name-only feat/REQ-0001-later | grep -c '^src$')" "1"
WU="$M/.claude/worktrees/upgrade-REQ-0001"
yes_ "a temporary worktree merges develop into the request branch" sh -c \
  "git worktree add -q '$WU' feat/REQ-0001-later && git -C '$WU' merge -q --no-ff develop -m 'Merge develop into feat/REQ-0001-later' && git worktree remove '$WU'"
eq_ "the request branch has the new layout" "$(git ls-tree --name-only feat/REQ-0001-later | grep -cE '^(src|projects)$')$(git ls-tree --name-only feat/REQ-0001-later | grep -c '^projects$')" "11"
eq_ "and still says ready" "$(status_of feat/REQ-0001-later:reqs/REQ-0001-20261007-later.md)" "ready"
WR="$M/.claude/worktrees/feat-REQ-0001-later"
yes_ "the start puts the project worktree in projects/" start "$M" "$WR" feat/REQ-0001-later feat/later origin/develop Mov
eq_ "the project worktree is on its project branch" "$(git -C "$WR/projects/Mov" branch --show-current)" "feat/later"
yes_ "and is removed in the usual order" rmwt "$M" "$WR"

sec "upgrade 0.9.0: the next release merge of develop into the main branch"
git checkout -q master; git submodule update -q
git merge -q --no-ff --no-commit develop >/dev/null 2>&1
echo "  NOTE  unmerged paths when develop meets the moved main branch: $(git diff --name-only --diff-filter=U | tr '\n' ' ')"
git update-index --cacheinfo "160000,$(git -C projects/Mov rev-parse origin/master),projects/Mov"
eq_ "update-index on the new path leaves no unmerged path" "$(git diff --name-only --diff-filter=U | count)" "0"
yes_ "the release merge commit can be created" git commit -q -m "Merge develop into master" -m "Release Mov v0.1.0"
eq_ "the main branch has no src/ left" "$(git ls-tree -r --name-only master | grep -c '^src/')" "0"
eq_ "and records the project's main branch in projects/" "$(git rev-parse master:projects/Mov)" "$(git -C projects/Mov rev-parse origin/master)"
git checkout -q develop; git submodule update -q
P_ALL="SSLib SSDisp"

# ================================================================ conversion of a <= 0.5.0 repository
L="$S/L"; W="$S/W"
sec "convert: a repository in the old layout, with a ready request, a closed one, and a draft"
git init -q --bare "$S/App.git"; git -C "$S/App.git" symbolic-ref HEAD refs/heads/master
git clone -q "$S/App.git" "$L" 2>/dev/null; cd "$L"; git checkout -q -b master
mkdir -p src/App tests/App.Test samples/App.Sample reqs/done docs
printf 'Project("App") = "App", "App\\App.csproj"\nProject("App.Test") = "App.Test", "..\\tests\\App.Test\\App.Test.csproj"\n' > src/App.sln
echo "app" > src/App/app.cs; echo "test" > tests/App.Test/test.cs; echo "sample" > samples/App.Sample/sample.cs
for d in . src reqs tests samples; do echo "ss-workflow agent file" > "$d/AGENTS.md"; echo "@AGENTS.md" > "$d/CLAUDE.md"; done
echo "ss-workflow-version: 0.5.0" >> AGENTS.md
echo "spec" > docs/app-spec.md; echo "manual" > docs/manual.md; echo "# App" > README.md
printf ".claude/worktrees/\nbin/\n" > .gitignore
mkreq 0000 old-one feat App; sed -i '/^projects:/d; s/^status: .*/status: done/' reqs/REQ-0000-20261007-old-one.md
git mv -f reqs/REQ-0000-20261007-old-one.md reqs/done/ 2>/dev/null || mv reqs/REQ-0000-20261007-old-one.md reqs/done/
git add -A 2>/dev/null; git commit -q -m "chore: initial commit"; git tag -a v0.1.0 -m "Release v0.1.0"
git branch develop; git checkout -q develop
mkreq 0001 ready-one feat App; sed -i '/^projects:/d; s/^status: .*/status: ready/' reqs/REQ-0001-20261007-ready-one.md
git add -A 2>/dev/null; git commit -q -m "docs(reqs): add REQ-0001"
git checkout -q -b req/REQ-0002-draft develop; mkreq 0002 draft feat App; sed -i '/^projects:/d' reqs/REQ-0002-20261007-draft.md
git add -A 2>/dev/null; git commit -q -m "docs(reqs): add draft REQ-0002"; git checkout -q develop
git push -q -u origin master develop req/REQ-0002-draft v0.1.0 2>/dev/null
eq_ "precondition: no request branch other than req/ drafts" "$(git branch -a --list '*REQ-*' --format='%(refname:short)' | grep -v 'req/' | count)" "0"
eq_ "precondition: no release or hotfix branch" "$(git branch -a --list '*release/*' --list '*hotfix/*' | count)" "0"
eq_ "precondition: no worktree besides the root checkout" "$(git worktree list | count)" "1"
BASE=$(git rev-parse develop)

sec "convert: the source repository goes back to the toolchain's layout"
git mv src/App.sln App.sln; git mv src/App App; git mv tests/App.Test App.Test
sed -i 's#\.\.\\tests\\App\.Test\\#App.Test\\#' App.sln
git rm -r -q samples
git commit -q -m "refactor: move the projects back to the Visual Studio layout" -m "samples/App.Sample was deleted at the developer's choice."
yes_ "history follows the moved file" sh -c "[ \$(git log --follow --oneline -- App/app.cs | wc -l) -ge 2 ]"
yes_ "the solution's path to the test project is fixed" grep -q '"App.Test\\App.Test.csproj"' App.sln
git rm -r -q reqs AGENTS.md CLAUDE.md src tests docs/app-spec.md
git commit -q -m "chore: remove the ss-workflow files" -m "They moved to the App-workspace repository."
git push -q origin develop 2>/dev/null
eq_ "the source repository has no ss-workflow files left on develop" "$(git ls-tree -r --name-only develop | grep -cE '^(reqs/|AGENTS.md|CLAUDE.md|src/|tests/)')" "0"
eq_ "the product docs stay" "$(git show develop:docs/manual.md)" "manual"
eq_ "the old tag is kept" "$(git describe --tags --abbrev=0 master)" "v0.1.0"
eq_ "master is unchanged until the next release" "$(git ls-tree --name-only master | tr '\n' ' ')" ".gitignore AGENTS.md CLAUDE.md README.md docs reqs samples src tests "

sec "convert: the new workspace takes the requests"
git init -q --bare "$S/W.git"; git -C "$S/W.git" symbolic-ref HEAD refs/heads/master
git clone -q "$S/W.git" "$W" 2>/dev/null; cd "$W"; git checkout -q -b master
git submodule add -q "$S/App.git" projects/App
git -C "$L" archive "$BASE" reqs | tar -x
mkdir -p docs/App; git -C "$L" show "$BASE:docs/app-spec.md" > docs/App/spec.md
for x in reqs/AGENTS.md reqs/CLAUDE.md; do echo "new template" > "$x"; done
for r in reqs/REQ-*.md; do sed -i 's/^type: \(.*\)$/type: \1\nprojects: [App]/' "$r"; done
git -C projects/App checkout -q --detach origin/master; git add -A 2>/dev/null
git commit -q -m "chore(workspace): import the requests of App" -m "Imported from App@$(git -C "$L" rev-parse --short "$BASE")."
git tag -a App/v0.1.0 -m "Release App v0.1.0"
git branch develop; git checkout -q develop
git -C projects/App checkout -q --detach origin/develop; git add projects/App; git commit -q -m "chore(workspace): point App to develop"
eq_ "the workspace master points to the released App" "$(git rev-parse master:projects/App)" "$(git -C projects/App rev-parse 'v0.1.0^{commit}')"
eq_ "the closed request is copied byte for byte" "$(git show develop:reqs/done/REQ-0000-20261007-old-one.md | md5sum)" "$(git -C "$L" show "$BASE:reqs/done/REQ-0000-20261007-old-one.md" | md5sum)"
eq_ "the old spec becomes the project's spec in the workspace" "$(git show develop:docs/App/spec.md)" "spec"
eq_ "the ready request gets its project" "$(git show develop:reqs/REQ-0001-20261007-ready-one.md | sed -n 's/^projects: //p')" "[App]"
eq_ "and keeps its status" "$(status_of develop:reqs/REQ-0001-20261007-ready-one.md)" "ready"
git checkout -q -b feat/REQ-0002-draft develop
git -C "$L" show "req/REQ-0002-draft:reqs/REQ-0002-20261007-draft.md" | sed 's/^type: \(.*\)$/type: \1\nprojects: [App]/' > reqs/REQ-0002-20261007-draft.md
git add reqs; git commit -q -m "docs(reqs): move draft REQ-0002 from App" -m "Refs: REQ-0002"; git checkout -q develop
git push -q -u origin master develop feat/REQ-0002-draft App/v0.1.0 2>/dev/null
yes_ "the draft lives on its request branch in the workspace" git ls-remote --exit-code --heads origin feat/REQ-0002-draft
ids=$( { git ls-tree -r --name-only develop reqs/; git branch -a --format='%(refname:short)'; } | grep -o 'REQ-[0-9]\{4\}' | sort -u | tail -1)
eq_ "the id scan of the workspace continues after the imported ids" "$ids" "REQ-0002"
yes_ "the old draft branch can go once the copy is confirmed" sh -c "git -C '$L' push -q origin --delete req/REQ-0002-draft && git -C '$L' branch -q -D req/REQ-0002-draft"
eq_ "the workspace root checkout is clean" "$(git status --porcelain | count)" "0"

echo
echo "RESULT: $PASS passed, $FAIL failed"
cd /
if [ "$FAIL" -eq 0 ] && [ -z "$KEEP" ]; then
  rm -rf "$S"
else
  echo "sandbox kept: $S"
fi
[ "$FAIL" -eq 0 ]
