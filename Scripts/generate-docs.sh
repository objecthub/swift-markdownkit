#!/bin/bash
#
# Generates the static documentation site and prepares it for publishing with GitHub Pages.
#
# The site is published from the root of the `gh-pages` branch at
# https://objecthub.github.io/swift-markdownkit/. This script generates the site and copies it
# into a git worktree of branch `gh-pages` (in `.build/gh-pages`, which git ignores). It does
# not commit or push anything. To publish the result:
#
#   cd .build/gh-pages
#   git add -A
#   git commit -m "Update the documentation site"
#   git push -u origin gh-pages
#
# Run this script before a release (generate the site before tagging, since it documents the
# state of the current working copy).
#
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
SITE="$ROOT/.build/docs-site"
WORKTREE="$ROOT/.build/gh-pages"
BRANCH="gh-pages"

# 1. Generate the site. The Swift-DocC plugin is only added to Package.swift if this variable is set.
#    Package.resolved is tracked by git and SwiftPM adds the pins of the plugin to it, so it is
#    restored when the script ends.
RESOLVED_BACKUP="$(mktemp)"
cp Package.resolved "$RESOLVED_BACKUP"
trap 'cp "$RESOLVED_BACKUP" Package.resolved; rm -f "$RESOLVED_BACKUP"' EXIT
export MARKDOWNKIT_GENERATE_DOCS=1
rm -rf "$SITE"
swift package --allow-writing-to-directory "$SITE" \
  generate-documentation --target MarkdownKit \
  --disable-indexing \
  --transform-for-static-hosting \
  --hosting-base-path swift-markdownkit \
  --output-path "$SITE"

# 2. DocC does not generate a page for the root of the site; redirect it to the documentation.
#    (Pages for all other URLs are generated individually and are not affected.)
cat > "$SITE/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>MarkdownKit Documentation</title>
  <meta http-equiv="refresh" content="0; url=documentation/markdownkit/">
  <link rel="canonical" href="documentation/markdownkit/">
</head>
<body>
  <p>Redirecting to the <a href="documentation/markdownkit/">MarkdownKit documentation</a>&hellip;</p>
</body>
</html>
HTML

# 3. Serve the files as they are, without any Jekyll processing
touch "$SITE/.nojekyll"

# 4. DocC does not write the keys of its JSON files in a stable order. Sorting them (which does
#    not change the meaning of the files) makes the output reproducible, so regenerating the site
#    only changes the files whose content changed and the commits to `gh-pages` stay small.
python3 -I - "$SITE" <<'PYTHON'
import json, os, sys
for directory, _, names in os.walk(sys.argv[1]):
    for name in names:
        if name.endswith(".json"):
            path = os.path.join(directory, name)
            with open(path, encoding="utf-8") as file:
                data = json.load(file)
            with open(path, "w", encoding="utf-8") as file:
                json.dump(data, file, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
PYTHON

# 5. Make sure there is a worktree for the `gh-pages` branch
git worktree prune
if [ ! -e "$WORKTREE/.git" ]; then
  rm -rf "$WORKTREE"
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git worktree add "$WORKTREE" "$BRANCH"
  elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    git worktree add -b "$BRANCH" "$WORKTREE" "origin/$BRANCH"
  else
    # The branch does not exist yet; create it without any history (requires git 2.42)
    git worktree add --orphan -b "$BRANCH" "$WORKTREE"
  fi
fi

# 6. Replace the contents of the worktree with the new site (keeping the worktree's .git file)
rsync -a --delete --exclude '/.git' "$SITE/" "$WORKTREE/"

echo
echo "The documentation site is ready in .build/gh-pages. To publish it:"
echo "  cd .build/gh-pages && git add -A && git commit -m \"Update the documentation site\" && git push -u origin gh-pages"
