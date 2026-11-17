#!/usr/bin/env bash
# Builds a throwaway ss-workflow workspace for the skill evals of check-req
# (skills/check-req/evals/). It writes into the target folder:
#
#   remotes/ws.git, remotes/SSLib.git, remotes/SSDisp.git   bare remotes
#   ws/                                                       the root checkout
#
# The workspace files come from skills/init/templates, so the agent reads the same
# AGENTS.md files as in a real workspace. Each scenario seeds a different set of
# requests:
#
#   overview        six requests in every status: a ready hotfix (low priority), a
#                   ready fix (high), a ready feature (normal), an in-progress feature
#                   with its worktree, a draft, and a request in review
#   start           one ready feature with a complete spec, on SSLib
#   resume-anomaly  an in-progress feature that a review sent back for rework; the
#                   root checkout was left on its request branch, no worktree exists
#   start-hotfix    a ready hotfix of SSDisp v0.1.0; SSDisp develop and the workspace
#                   develop have moved on since the release
#   overview-dependency
#                   a ready fix (high) that depends on a ready feature (normal), a
#                   ready chore (low), and an in-progress feature that was started on
#                   another machine (its branches exist only on the remotes)
#   start-push-never
#                   the start scenario, with push-policy never for SSLib
#
# Usage:  bash tests/eval-fixtures/check-req-workspace.sh <scenario> [target folder]
set -eu
SCENARIO="${1:?usage: check-req-workspace.sh <scenario> [target]}"
TARGET="${2:-.}"
HERE="$(cd "$(dirname "$0")" && pwd)"
TPL="$HERE/../../skills/init/templates"
mkdir -p "$TARGET"; cd "$TARGET"
T="$(pwd -W 2>/dev/null || pwd)"
[ -e "$T/ws" ] && { echo "already built: $T/ws" >&2; exit 1; }

# Keep line endings, allow folder URLs for submodules, and keep the fixture away from
# the developer's own git identity and hooks.
export GIT_CONFIG_COUNT=3 GIT_CONFIG_KEY_0=core.autocrlf GIT_CONFIG_VALUE_0=false \
  GIT_CONFIG_KEY_1=protocol.file.allow GIT_CONFIG_VALUE_1=always \
  GIT_CONFIG_KEY_2=init.defaultBranch GIT_CONFIG_VALUE_2=master
export GIT_AUTHOR_NAME="Eval Developer" GIT_AUTHOR_EMAIL="dev@example.invalid"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
export GIT_AUTHOR_DATE="2026-11-01T09:00:00" GIT_COMMITTER_DATE="2026-11-01T09:00:00"

R="$T/remotes"; W="$T/ws"
mkdir -p "$R"

# ------------------------------------------------------------------ projects
seed_project() { # name -> bare remote with master (tag v0.1.0) and develop
  local n=$1 s="$T/seed-$1"
  git init -q --bare "$R/$n.git"
  git init -q "$s"
  ( cd "$s"
    printf '0.1.0\n' > version.txt
    printf '%s core\n' "$n" > app.txt
    printf '# %s\n\nA sample project. `bash build.sh` joins every .txt file into bin/out.txt.\n' "$n" > README.md
    cat > build.sh <<'EOF'
#!/usr/bin/env bash
# Joins every text file of the project into bin/out.txt.
set -eu
mkdir -p bin
cat *.txt > bin/out.txt
echo "build ok: $(wc -l < bin/out.txt) lines"
EOF
    printf 'bin/\n' > .gitignore
    git add -A; git commit -q -m "chore: initial commit"
    git tag -a v0.1.0 -m "v0.1.0"
    git branch develop
    git remote add origin "$R/$n.git"; git push -q origin master develop v0.1.0 )
  rm -rf "$s"
}
seed_project SSLib
seed_project SSDisp

# ------------------------------------------------------------------ workspace files
entry() { # name [push-policy]
  sed -e "s#{{ENTRY_PUSH_POLICY}}#${2:-}#" \
      -e "s#{{ENTRY_NAME}}#$1#g" -e "s#{{ENTRY_MAIN_BRANCH}}#master#" -e "s#{{ENTRY_DEVELOP_BRANCH}}#develop#" \
      -e "s#{{ENTRY_TYPE}}#Text files joined by a bash script#" -e "s#{{ENTRY_KIND}}#library#" \
      -e "s#{{ENTRY_PROJECT_FILE}}##" -e "s#{{ENTRY_VERSION_SOURCE}}#version.txt#" \
      -e "s#{{ENTRY_SETUP_COMMAND}}##" -e "s#{{ENTRY_BUILD_COMMAND}}#bash build.sh#" \
      -e "s#{{ENTRY_TEST_COMMAND}}##" -e "s#{{ENTRY_PACKAGE_COMMAND}}##" -e "s#{{ENTRY_PACKAGE_FILES}}##" \
      -e "s#{{ENTRY_REMOTE_PLATFORM}}##" -e "s#{{ENTRY_MERGE_METHOD}}##" -e "s#{{ENTRY_PUSH_POLICY}}##" \
      "$TPL/projects-entry.yaml"
}
section() { # name description
  sed -e "s#{{ENTRY_NAME}}#$1#g" -e "s#{{ENTRY_DESCRIPTION}}#$2#" -e "s#{{ENTRY_URL}}#$R/$1.git#" \
      -e "s#{{ENTRY_TYPE}}#Text files joined by a bash script#" \
      -e "s#{{ENTRY_TOOLCHAIN_NOTES}}#Git Bash. Nothing else.#" \
      -e "s#{{ENTRY_PROJECT_RULES}}#Every .txt file in the project root is part of the build output; no registration is needed. bin/ is build output.#" \
      "$TPL/projects-AGENTS-project.md"
}

git init -q "$W"; cd "$W"
SSLIB_PUSH=""; [ "$SCENARIO" = start-push-never ] && SSLIB_PUSH=never
{ entry SSLib "$SSLIB_PUSH"; entry SSDisp; } > "$T/projects.yaml"
{ section SSLib "The shared library."; section SSDisp "The display application, which uses SSLib."; } > "$T/sections.md"
sed -e "s#{{WORKSPACE_NAME}}#demo-workspace#g" \
    -e "s#{{WORKSPACE_DESCRIPTION}}#A demo workspace with a library and a display application.#" \
    -e "s#{{SS_WORKFLOW_VERSION}}#0.12.4#" -e "s#{{INIT_DATE}}#2026-10-01#" \
    -e "s#{{DISCUSSION_LANG}}#zh-TW#" -e "s#{{README_LANGS}}#en#" -e "s#{{AGENT_DOC_LANG}}#en#" \
    -e "s#{{REQS_LANG}}#en#" -e "s#{{DOCS_LANG}}#en#" -e "s#{{MAIN_BRANCH}}#master#" \
    -e "s#{{REMOTE_PLATFORM}}#none#" -e "s#{{REMOTE_CLI}}##" -e "s#{{MERGE_METHOD}}#local#" \
    -e "s#{{PUSH_POLICY}}#auto#" -e "s#{{LEGACY_PROJECT}}##" \
    "$TPL/root-AGENTS.md" | awk -v f="$T/projects.yaml" '
      /\{\{PROJECTS\}\}/ { sub(/\{\{PROJECTS\}\}/, ""); print; while ((getline l < f) > 0) print l; next } { print }' > AGENTS.md
mkdir -p projects
sed -e "s#{{WORKSPACE_NAME}}#demo-workspace#g" "$TPL/projects-AGENTS.md" \
  | awk -v f="$T/sections.md" '/\{\{PROJECT_SECTIONS\}\}/ { while ((getline l < f) > 0) print l; next } { print }' > projects/AGENTS.md
rm -f "$T/projects.yaml" "$T/sections.md"
mkdir -p reqs/done docs/SSLib docs/SSDisp; touch reqs/done/.gitkeep
cp "$TPL/reqs-AGENTS.md" reqs/AGENTS.md
cp "$TPL/CLAUDE.md" CLAUDE.md
printf '# Overview\n\nSSLib is a library of text files. SSDisp is an application that uses SSLib.\n' > docs/overview.md
printf '# SSLib spec\n\nSSLib holds `app.txt` and `version.txt`. Every .txt file is part of its build output.\n' > docs/SSLib/spec.md
printf '# SSDisp spec\n\nSSDisp holds `app.txt` and `version.txt`. Every .txt file is part of its build output.\n' > docs/SSDisp/spec.md
printf '.claude/worktrees/\n' > .gitignore
git submodule add -q "$R/SSLib.git" projects/SSLib
git submodule add -q "$R/SSDisp.git" projects/SSDisp
git add -A; git commit -q -m "chore: add ss-workflow workspace"
git tag -a SSLib/v0.1.0 -m "SSLib v0.1.0"; git tag -a SSDisp/v0.1.0 -m "SSDisp v0.1.0"
git branch develop; git checkout -q develop
for p in SSLib SSDisp; do git -C "projects/$p" checkout -q --detach origin/develop; done
git commit -q --allow-empty -m "chore(workspace): point the projects to develop"
git init -q --bare "$R/ws.git"
git remote add origin "$R/ws.git"
git push -q -u origin master develop SSLib/v0.1.0 SSDisp/v0.1.0
git -C "$R/ws.git" symbolic-ref HEAD refs/heads/develop

# ------------------------------------------------------------------ request helpers
sha_of() { git -C "projects/$1" rev-parse --short origin/develop; }
# reqfile id slug type projects priority title spec-body [notes]
reqfile() {
  local f="reqs/REQ-$1-20261101-$2.md"
  cat > "$f" <<EOF
---
id: REQ-$1
title: $6
status: draft
type: $3
projects: [$4]
priority: $5
branch:
project-branch:
created: 2026-11-01
---

# $6

## Spec

$7

## Original

$6.

## Q&A

## Evidence

### E1 (2026-11-01): the build joins every .txt file of a project into bin/out.txt
- Status: verified
- Evidence: \`SSLib@$(sha_of SSLib):build.sh:5\`
  > \`cat *.txt > bin/out.txt\`
- Used by: Spec "Architecture"
- History:
  - 2026-11-01 created as verified (new-req)

## Notes
${8:-}
EOF
  echo "$f"
}
simple_spec() { # project file line goal [hotfix line]
  cat <<EOF
### Goal

$4

### Scope

${5:+$5

}- $1: a new file \`$2\` that holds the line \`$3\`.

### Architecture

No architectural decision: a new text file in the root of $1, which the build picks up (E1).

### Detailed design

#### File changes

| Project | Path | Action | Content |
|---------|------|--------|---------|
| $1 | \`$2\` | Add | One line: \`$3\` |

#### Types and public members

None.

#### Data and state

None.

#### Flows

None.

#### Errors and edge cases

None.

#### Configuration and dependencies

None.

#### Tests

$1 has no automated tests. The check is manual (see "How to verify").

#### Left to the implementation

Nothing.

### Acceptance criteria

- [ ] \`$1/$2\` holds exactly the line \`$3\`.
- [ ] \`bash build.sh\` in $1 puts the line into \`bin/out.txt\`.

### How to verify

- Review: run \`bash build.sh\` in $1 and look for the line in \`bin/out.txt\`.

### Out of scope

Everything else.
EOF
}
farewell_spec() { # the two-project spec of REQ-0003
  cat <<'EOF'
### Goal

SSDisp says goodbye, with the text that SSLib provides.

### Scope

- SSLib: a new file `farewell-api.txt` that holds the line `farewell api`.
- SSDisp: a new file `farewell.txt` that holds the line `Goodbye from SSDisp`.

### Architecture

No architectural decision: one new text file in the root of each project, which the build picks up (E1). SSDisp does not read the SSLib file at build time.

### Detailed design

#### File changes

| Project | Path | Action | Content |
|---------|------|--------|---------|
| SSLib | `farewell-api.txt` | Add | One line: `farewell api` |
| SSDisp | `farewell.txt` | Add | One line: `Goodbye from SSDisp` |

#### Types and public members

None.

#### Data and state

None.

#### Flows

None.

#### Errors and edge cases

None.

#### Configuration and dependencies

None.

#### Tests

Neither project has automated tests. The checks are manual (see "How to verify").

#### Left to the implementation

Nothing.

### Acceptance criteria

- [ ] `SSLib/farewell-api.txt` holds exactly the line `farewell api`.
- [ ] `SSDisp/farewell.txt` holds exactly the line `Goodbye from SSDisp`.

### How to verify

- Review: run `bash build.sh` in each project and look for the line in `bin/out.txt`.

### Out of scope

Everything else.
EOF
}
draft() { # branch file-producing-command... -> request branch from develop with the draft commit
  local b=$1; shift
  git checkout -q -b "$b" develop
  local f; f=$("$@")
  git add -A; git commit -q -m "docs(reqs): add draft ${f#reqs/}" -m "Refs: $(sed -n 's/^id: //p' "$f")"
  echo "$f"
}
setfield() { sed -i "s#^$2:.*#$2: $3#" "$1"; }
approve() { # file id
  setfield "$1" status ready
  git commit -q -am "docs(reqs): approve $2" -m "Refs: $2"
}
start_req() { # file id branch project-branch projects... -> start commit + project branches with one commit each
  local f=$1 id=$2 b=$3 pb=$4 p; shift 4
  setfield "$f" status in-progress; setfield "$f" branch "$b"; setfield "$f" project-branch "$pb"
  git commit -q -am "chore(reqs): start $id" -m "Refs: $id"
  for p in "$@"; do git -C "projects/$p" fetch -q; git -C "projects/$p" branch -q --no-track "$pb" origin/develop; done
}
project_commit() { # project branch file line message
  local p=$1 tmp="$T/tmp-$1"
  git -C "projects/$p" worktree add -q "$tmp" "$2"
  ( cd "$tmp"; printf '%s\n' "$4" > "$3"; git add -A; git commit -q -m "$5"; git push -q -u origin "$2" )
  git -C "projects/$p" worktree remove "$tmp"
}

case "$SCENARIO" in
# ================================================================== overview
overview)
  f1=$(draft feat/REQ-0001-add-greeting reqfile 0001 add-greeting feat SSLib normal "Add a greeting" "$(simple_spec SSLib greeting.txt 'Hello from SSLib' 'SSLib greets its users.')")
  approve "$f1" REQ-0001; git push -q -u origin feat/REQ-0001-add-greeting
  f2=$(draft fix/REQ-0002-fix-title reqfile 0002 fix-title fix SSDisp high "Fix the window title" "$(simple_spec SSDisp title.txt 'SSDisp Viewer' 'The window title is wrong.')")
  approve "$f2" REQ-0002; git push -q -u origin fix/REQ-0002-fix-title
  # REQ-0003: in progress, with its worktree, one commit in each project
  f3=$(draft feat/REQ-0003-add-farewell reqfile 0003 add-farewell feat "SSLib, SSDisp" normal "Add a farewell" "$(farewell_spec)")
  approve "$f3" REQ-0003
  start_req "$f3" REQ-0003 feat/REQ-0003-add-farewell feat/add-farewell SSLib SSDisp
  git push -q -u origin feat/REQ-0003-add-farewell
  project_commit SSLib feat/add-farewell farewell-api.txt "farewell api" "feat: add the farewell text"
  project_commit SSDisp feat/add-farewell farewell.txt "Goodbye from SSDisp" "feat: show a farewell"
  git checkout -q develop; git submodule update -q
  wt="$W/.claude/worktrees/feat-REQ-0003-add-farewell"
  git worktree add -q "$wt" feat/REQ-0003-add-farewell
  for p in SSLib SSDisp; do git -C "projects/$p" worktree add -q "$wt/projects/$p" feat/add-farewell; done
  # REQ-0004: a draft
  draft feat/REQ-0004-dark-mode reqfile 0004 dark-mode feat SSDisp normal "Dark mode" "(under discussion)" >/dev/null
  git push -q -u origin feat/REQ-0004-dark-mode
  # REQ-0005: in review, worktrees removed
  f5=$(draft feat/REQ-0005-log-level reqfile 0005 log-level feat SSLib normal "Add a log level" "$(simple_spec SSLib loglevel.txt 'info' 'SSLib needs a log level.')")
  approve "$f5" REQ-0005
  start_req "$f5" REQ-0005 feat/REQ-0005-log-level feat/log-level SSLib
  project_commit SSLib feat/log-level loglevel.txt "info" "feat: add a log level"
  git -C projects/SSLib fetch -q
  git update-index --cacheinfo "160000,$(git -C projects/SSLib rev-parse origin/feat/log-level),projects/SSLib"
  setfield "$f5" status review
  git add reqs; git commit -q -m "chore(reqs): mark REQ-0005 for review" -m "Refs: REQ-0005"
  git push -q -u origin feat/REQ-0005-log-level
  # REQ-0006: a ready hotfix with low priority
  f6=$(draft hotfix/REQ-0006-fix-crash reqfile 0006 fix-crash hotfix SSDisp low "Fix the crash on start" "$(simple_spec SSDisp crashfix.txt 'no crash on start' 'SSDisp v0.1.0 crashes on start.' 'Hotfix: SSDisp v0.1.0 → v0.1.1')")
  approve "$f6" REQ-0006; git push -q -u origin hotfix/REQ-0006-fix-crash
  git checkout -q develop; git submodule update -q
  ;;
# ================================================================== start
start)
  f1=$(draft feat/REQ-0001-add-greeting reqfile 0001 add-greeting feat SSLib normal "Add a greeting" "$(simple_spec SSLib greeting.txt 'Hello from SSLib' 'SSLib greets its users.')")
  approve "$f1" REQ-0001; git push -q -u origin feat/REQ-0001-add-greeting
  git checkout -q develop; git submodule update -q
  ;;
# ================================================================== resume-anomaly
resume-anomaly)
  review_note="
### Implementation summary (2026-11-05)
- What changed: SSLib: farewell-api.txt; SSDisp: farewell.txt; workspace files: none
- Ran in the worktree: bash build.sh in SSLib passed; bash build.sh in SSDisp passed

### Review (2026-11-08)
- Result: sent back for rework
- Finding 1: \`SSDisp/farewell.txt\` holds \`Bye\`, but the spec asks for \`Goodbye from SSDisp\`."
  f3=$(draft feat/REQ-0003-add-farewell reqfile 0003 add-farewell feat "SSLib, SSDisp" normal "Add a farewell" "$(farewell_spec)" "$review_note")
  approve "$f3" REQ-0003
  start_req "$f3" REQ-0003 feat/REQ-0003-add-farewell feat/add-farewell SSLib SSDisp
  project_commit SSLib feat/add-farewell farewell-api.txt "farewell api" "feat: add the farewell text"
  project_commit SSDisp feat/add-farewell farewell.txt "Bye" "feat: show a farewell"
  for p in SSLib SSDisp; do git -C "projects/$p" fetch -q
    git update-index --cacheinfo "160000,$(git -C "projects/$p" rev-parse origin/feat/add-farewell),projects/$p"; done
  git add reqs; git commit -q -m "chore(reqs): reopen REQ-0003 after the review" -m "Refs: REQ-0003"
  git push -q -u origin feat/REQ-0003-add-farewell
  # The review left the root checkout on the request branch, the projects on their branches.
  for p in SSLib SSDisp; do git -C "projects/$p" checkout -q feat/add-farewell 2>/dev/null \
    || git -C "projects/$p" checkout -q -b feat/add-farewell --track origin/feat/add-farewell; done
  ;;
# ================================================================== start-hotfix
start-hotfix)
  # Since the release, SSDisp develop and the workspace develop have moved on.
  s="$T/tmp-SSDisp"; git -C projects/SSDisp worktree add -q --detach "$s" origin/develop
  ( cd "$s"; printf 'next feature
' > next.txt; git add -A; git commit -q -m "feat: start the next feature"; git push -q origin HEAD:develop )
  git -C projects/SSDisp worktree remove "$s"; git -C projects/SSDisp fetch -q
  git -C projects/SSDisp checkout -q --detach origin/develop
  git add projects/SSDisp; git commit -q -m "chore(workspace): update the SSDisp gitlink"; git push -q
  f6=$(draft hotfix/REQ-0006-fix-crash reqfile 0006 fix-crash hotfix SSDisp normal "Fix the crash on start" "$(simple_spec SSDisp crashfix.txt 'no crash on start' 'SSDisp v0.1.0 crashes on start.' 'Hotfix: SSDisp v0.1.0 → v0.1.1')")
  approve "$f6" REQ-0006; git push -q -u origin hotfix/REQ-0006-fix-crash
  git checkout -q develop; git submodule update -q
  ;;
# ================================================================== overview-dependency
overview-dependency)
  f1=$(draft feat/REQ-0001-add-greeting reqfile 0001 add-greeting feat SSLib normal "Add a greeting" "$(simple_spec SSLib greeting.txt 'Hello from SSLib' 'SSLib provides a greeting for SSDisp.')")
  approve "$f1" REQ-0001; git push -q -u origin feat/REQ-0001-add-greeting
  dep="$(simple_spec SSDisp title.txt 'SSDisp Viewer - Hello from SSLib' 'The window title shows the SSLib greeting.' | sed 's#^No architectural decision:.*#SSDisp needs the greeting of SSLib that REQ-0001 adds (`greeting.txt`); this request can only be built after REQ-0001. Otherwise no architectural decision: a new text file in the root of SSDisp, which the build picks up (E1).#')"
  f2=$(draft fix/REQ-0002-fix-title reqfile 0002 fix-title fix SSDisp high "Fix the window title" "$dep")
  approve "$f2" REQ-0002; git push -q -u origin fix/REQ-0002-fix-title
  f7=$(draft chore/REQ-0007-tidy-readme reqfile 0007 tidy-readme chore SSLib low "Tidy the README" "$(simple_spec SSLib notes.txt 'tidy' 'The README of SSLib is untidy.')")
  approve "$f7" REQ-0007; git push -q -u origin chore/REQ-0007-tidy-readme
  # REQ-0003 was started on another machine: its branches exist only on the remotes.
  f3=$(draft feat/REQ-0003-add-farewell reqfile 0003 add-farewell feat "SSLib, SSDisp" normal "Add a farewell" "$(farewell_spec)")
  approve "$f3" REQ-0003
  start_req "$f3" REQ-0003 feat/REQ-0003-add-farewell feat/add-farewell SSLib SSDisp
  git push -q -u origin feat/REQ-0003-add-farewell
  project_commit SSLib feat/add-farewell farewell-api.txt "farewell api" "feat: add the farewell text"
  git -C projects/SSDisp push -q -u origin feat/add-farewell
  git checkout -q develop; git submodule update -q
  git branch -q -D feat/REQ-0003-add-farewell
  for p in SSLib SSDisp; do git -C "projects/$p" branch -q -D feat/add-farewell; git -C "projects/$p" fetch -q; done
  ;;
# ================================================================== start-push-never
start-push-never)
  f1=$(draft feat/REQ-0001-add-greeting reqfile 0001 add-greeting feat SSLib normal "Add a greeting" "$(simple_spec SSLib greeting.txt 'Hello from SSLib' 'SSLib greets its users.')")
  approve "$f1" REQ-0001; git push -q -u origin feat/REQ-0001-add-greeting
  git checkout -q develop; git submodule update -q
  ;;
*) echo "unknown scenario: $SCENARIO" >&2; exit 1 ;;
esac
echo "fixture ready: $W ($SCENARIO)"
