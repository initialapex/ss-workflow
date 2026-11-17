#!/usr/bin/env bash
# Builds the workspace of this test (ws/ and remotes/) in the current folder.
set -eu
bash "$(dirname "$0")/../../../../tests/eval-fixtures/check-req-workspace.sh" start-hotfix .
