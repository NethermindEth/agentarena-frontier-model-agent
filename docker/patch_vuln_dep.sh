#!/usr/bin/env bash
#
# patch_vuln_dep.sh NAME FIXED_VERSION [SEARCH_ROOTS]
#
# Replace every vendored copy of an npm package found under SEARCH_ROOTS with a
# fixed version, in place. This is meant for vulnerable *transitive* deps that
# are bundled inside third-party CLIs (e.g. cursor-agent vendors `piscina`, the
# global npm/other CLIs vendor `picomatch`) and therefore cannot be upgraded
# with a normal `npm install` in this project.
#
# The whole package directory is swapped out (not just the version string in
# package.json) so the vulnerable code is actually removed, and only copies that
# share the SAME MAJOR version as FIXED and are older than it are touched, so the
# package API never changes (a "close range" patch, e.g. 4.0.3 -> 4.0.4).
#
#   patch_vuln_dep.sh picomatch 4.0.4 "/usr /home /opt"
#   patch_vuln_dep.sh piscina   4.9.3 "/usr /home /opt"
#
set -euo pipefail

NAME="${1:?package name required}"
FIXED="${2:?fixed version required}"
ROOTS="${3:-/}"

fixed_major="${FIXED%%.*}"

# Stage the fixed version once, then reuse it for every copy we replace.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
( cd "$STAGE" && npm pack "${NAME}@${FIXED}" >/dev/null )
TARBALL="$(ls "$STAGE"/*.tgz)"
mkdir -p "$STAGE/extract"
tar -xzf "$TARBALL" -C "$STAGE/extract"   # npm tarballs extract to ./package/

patched=0
for root in $ROOTS; do
  [ -d "$root" ] || continue
  while IFS= read -r pkgjson; do
    dir="$(dirname "$pkgjson")"
    cur="$(node -e "process.stdout.write(String(require('$pkgjson').version||''))" 2>/dev/null || true)"
    [ -n "$cur" ] || continue

    # Stay within the same major version (close-range patch only).
    [ "${cur%%.*}" = "$fixed_major" ] || continue

    # Skip copies already at or beyond the fix; never downgrade.
    lowest="$(printf '%s\n%s\n' "$cur" "$FIXED" | sort -V | head -n1)"
    if [ "$cur" = "$FIXED" ] || [ "$lowest" != "$cur" ]; then
      continue
    fi

    rm -rf "$dir"
    mkdir -p "$dir"
    cp -a "$STAGE/extract/package/." "$dir/"
    echo "patched: $dir ($cur -> $FIXED)"
    patched=$((patched + 1))
  done < <(find "$root" -type f -path "*/node_modules/${NAME}/package.json" 2>/dev/null)
done

echo "${NAME}: patched ${patched} cop(y/ies) to ${FIXED} under [${ROOTS}]"
