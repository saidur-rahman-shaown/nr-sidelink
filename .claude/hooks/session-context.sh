#!/usr/bin/env bash
echo "branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'not a git repo')"
echo "uncommitted: $(git status --porcelain 2>/dev/null | wc -l) files"
if [ -f cfg/specVersions.json ]; then
  echo "--- frozen spec versions ---"; cat cfg/specVersions.json
else
  echo "WARNING: cfg/specVersions.json missing. Spec versions are not frozen; clause pointers are unverified."
fi
n=$(grep -rl "pending-human" +test 2>/dev/null | wc -l)
echo "worked examples awaiting human verification: $n file(s)"
