#!/usr/bin/env bash
# Checks that a change to the templates ships a migration file.
#
# The files under skills/init/templates/ end up in other repositories, and a plugin
# update does not reach them. When they changed since the last release tag, a file
# skills/init/migrations/<version>.md must exist for a version that is higher than
# that tag. The script also checks that every migration file has the three parts
# that references/upgrade.md reads.
#
# Usage:  bash tests/migrations.sh
cd "$(dirname "$0")/.." || exit 1
FAIL=0
ok() { echo "  PASS  $1"; }
ng() { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
higher() { # a b -> true when version a is higher than version b
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

M=skills/init/migrations
plugin=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)
last=$(git tag -l 'v*' | sed 's/^v//' | sort -V | tail -1)
echo "plugin version: $plugin, last release tag: ${last:+v}${last:-none}"

echo
echo "== format of the migration files"
for file in "$M"/[0-9]*.md; do
  [ -e "$file" ] || continue
  v=$(basename "$file" .md)
  head -1 "$file" | tr -d '\r' | grep -qx "# Migration to $v" && ok "$v: title names its version" || ng "$v: the first line must be '# Migration to $v'"
  for part in "## What changes" "## Steps" "## Check"; do
    tr -d '\r' < "$file" | grep -qx "$part" && ok "$v: has '$part'" || ng "$v: '$part' is missing"
  done
done

echo
echo "== a template change needs a migration file"
if [ -z "$last" ]; then
  ok "no release tag yet: nothing to compare with"
else
  changed=$( { git diff --name-only "v$last" -- skills/init/templates; git ls-files --others --exclude-standard -- skills/init/templates; } | sort -u)
  if [ -z "$changed" ]; then
    ok "the templates did not change since v$last"
  else
    echo "  changed since v$last:"; echo "$changed" | sed 's/^/    /'
    newer=""
    for file in "$M"/[0-9]*.md; do
      [ -e "$file" ] || continue
      v=$(basename "$file" .md)
      higher "$v" "$last" && newer="$newer $v"
    done
    [ -n "$newer" ] && ok "migration file for a version after v$last:$newer" \
      || ng "the templates changed since v$last, but $M has no file for a higher version"
  fi
fi

echo
echo "== no migration file is ahead of the next release"
for file in "$M"/[0-9]*.md; do
  [ -e "$file" ] || continue
  v=$(basename "$file" .md)
  if higher "$v" "$plugin"; then
    echo "  NOTE  $v is higher than the plugin version $plugin: it applies once the plugin is released as $v"
  fi
done

echo
[ "$FAIL" -eq 0 ] && echo "RESULT: ok" || echo "RESULT: $FAIL failed"
[ "$FAIL" -eq 0 ]
