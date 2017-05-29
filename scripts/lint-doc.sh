#!/usr/bin/env bash

cd "$(dirname "$0")/.."

# Use long options (e.g. --header instead of -H) for curl examples in documentation.
grep --extended-regexp --recursive --color=auto 'curl (.+ )?-[^- ].*' doc/
if [ $? == 0 ]
then
  echo '✖ ERROR: Short options should not be used in documentation!' >&2
  exit 1
fi

# Ensure that the CHANGELOG.md does not contain duplicate versions
DUPLICATE_CHANGELOG_VERSIONS=$(grep --extended-regexp '^## .+' CHANGELOG.md | sed -E 's| \(.+\)||' | sort -r | uniq -d)
if [ "${DUPLICATE_CHANGELOG_VERSIONS}" != "" ]
then
  echo '✖ ERROR: Duplicate versions in CHANGELOG.md:' >&2
  echo "${DUPLICATE_CHANGELOG_VERSIONS}" >&2
  exit 1
fi

echo "✔ Linting passed"
exit 0
