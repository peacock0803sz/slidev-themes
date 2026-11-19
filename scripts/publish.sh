#!/usr/bin/env bash
# Usage: bash scripts/publish.sh <version> [--dry-run]
#
# Publishes the committed state (HEAD) instead of the working tree, so a
# release never includes uncommitted edits and never leaves files behind.
set -euo pipefail

REGISTRY=https://registry.npmjs.org/
REPO_URL=git+https://github.com/peacock0803sz/slidev-themes.git

usage() {
  echo "usage: bash scripts/publish.sh <version> [--dry-run]" >&2
  echo "  <version> must be X.Y.Z without a leading v or a pre-release suffix" >&2
  exit 1
}

version="${1:-}"
dry_run=""
case $# in
  1) ;;
  2)
    [ "$2" = "--dry-run" ] || usage
    dry_run="--dry-run"
    ;;
  *) usage ;;
esac
re='^[0-9]+\.[0-9]+\.[0-9]+$'
[[ $version =~ $re ]] || usage

# npm reads .npmrc from the directory it runs in; staying at the repository
# root keeps the per-theme pnpm settings (shamefully-hoist) away from npm.
cd "$(dirname "$0")/.." || exit 1

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
git archive HEAD themes LICENSE | tar -x -f - -C "$stage"

# Check every theme before publishing any of them. npm rejects a mismatched
# repository only at upload time, when earlier themes are already released.
errors=0
for pkg in "$stage"/themes/*/package.json; do
  rel="${pkg#"$stage"/}"
  rel="${rel%/package.json}"
  if ! jq -e --arg dir "$rel" --arg url "$REPO_URL" --arg registry "$REGISTRY" '
    (.name | split("/")[0]) as $scope
    | .repository.url == $url
      and .repository.directory == $dir
      and .publishConfig.access == "public"
      and .publishConfig[$scope + ":registry"] == $registry
  ' "$pkg" > /dev/null; then
    echo "error: $rel/package.json at HEAD needs repository.url \"$REPO_URL\", repository.directory \"$rel\", publishConfig.access \"public\" and publishConfig[\"<scope>:registry\"] \"$REGISTRY\"" >&2
    errors=$((errors + 1))
  fi
done
[ "$errors" -eq 0 ] || exit 1

for pkg in "$stage"/themes/*/package.json; do
  dir="${pkg%/package.json}"
  name="$(jq -r .name "$pkg")"

  # Ask the registry directly instead of running `npm view`: a user-level
  # .npmrc may point the scope at GitHub Packages, and an answer we cannot
  # interpret has to stop the release instead of triggering a publish.
  if ! code="$(curl -sS --retry 3 -o "$stage/packument.json" -w '%{http_code}' "$REGISTRY${name/\//%2f}")"; then
    echo "error: cannot reach $REGISTRY to check $name" >&2
    exit 1
  fi
  case "$code" in
    200)
      if jq -e --arg v "$version" '.versions[$v] != null' "$stage/packument.json" > /dev/null; then
        echo "skip: $name@$version is already published"
        continue
      fi
      ;;
    404) ;;
    *)
      echo "error: unexpected HTTP $code from $REGISTRY for $name" >&2
      exit 1
      ;;
  esac

  jq --arg v "$version" '.version = $v' "$pkg" > "$stage/package.json.tmp"
  mv "$stage/package.json.tmp" "$pkg"
  cp "$stage/LICENSE" "$dir/LICENSE"
  echo "publish: $name@$version"
  npm publish "$dir" ${dry_run:+"$dry_run"}
done
