#!/bin/sh
# Usage: prepare-release.sh <tag>
# Run from the repository root. Writes dist/mkwork.sh with the tag embedded as
# MKWORK_VERSION, plus dist/mkwork.sh.sha256.
set -eu

tag="${1-}"

# The tag is written into a double-quoted shell literal and a sed replacement,
# so allow only characters that are inert in both. This still accepts
# prerelease and build metadata such as v1.2.3-rc.1+build.5.
case "$tag" in
  ''|*[!A-Za-z0-9._+-]*)
    printf 'Invalid release tag: only A-Z a-z 0-9 . _ + - are allowed\n' >&2
    exit 1
    ;;
esac

mkdir -p dist
sed "s/^MKWORK_VERSION=\"[^\"]*\"/MKWORK_VERSION=\"$tag\"/" mkwork.sh > dist/mkwork.sh
(cd dist && sha256sum mkwork.sh > mkwork.sh.sha256)
