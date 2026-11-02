#!/usr/bin/env bash
# Vercel "Ignored Build Step" for the static site (chom.co.za).
# Exit 0 = skip this deployment. Exit 1 = build it.
#
# Skips only when nothing that affects the static site has changed since the
# last successful deployment. Whenever that can't be established, it builds.

paths=(static scripts/build.mjs scripts/vercel-ignore.sh vercel.json)
base="${VERCEL_GIT_PREVIOUS_SHA:-}"

if [ -z "$base" ]; then
  echo "No previous deployment to compare with: building."
  exit 1
fi

if ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
  echo "Previous deployment ${base} is not in this checkout: building."
  exit 1
fi

if git diff --quiet "$base" HEAD -- "${paths[@]}"; then
  echo "Static site unchanged since ${base}: skipping."
  exit 0
fi

echo "Static site changed since ${base}: building."
exit 1
