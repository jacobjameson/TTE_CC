#!/usr/bin/env bash
#
# TTE_CC installer — downloads the toolkit and links its Claude Code skills so you
# can use them on your machine.
#
# Quick install (skills available globally in Claude Code):
#   curl -fsSL https://raw.githubusercontent.com/jacobjameson/TTE_CC/main/install.sh | bash
#
# Install skills into the CURRENT project instead of globally:
#   curl -fsSL https://raw.githubusercontent.com/jacobjameson/TTE_CC/main/install.sh | \
#       TTE_CC_SKILLS_DEST="$PWD/.claude/skills" bash
#
# Env vars:
#   TTE_CC_HOME        where the toolkit is installed   (default: ~/.tte_cc)
#   TTE_CC_SKILLS_DEST where skills are linked           (default: ~/.claude/skills)
#
set -euo pipefail

REPO_URL="https://github.com/jacobjameson/TTE_CC"
TARBALL="${REPO_URL}/archive/refs/heads/main.tar.gz"
TTE_CC_HOME="${TTE_CC_HOME:-$HOME/.tte_cc}"
SKILLS_DEST="${TTE_CC_SKILLS_DEST:-$HOME/.claude/skills}"

echo "==> Installing TTE_CC into: $TTE_CC_HOME"
if command -v git >/dev/null 2>&1; then
  if [ -d "$TTE_CC_HOME/.git" ]; then
    echo "    updating existing checkout"
    git -C "$TTE_CC_HOME" pull --ff-only --quiet
  else
    rm -rf "$TTE_CC_HOME"
    git clone --depth 1 --quiet "${REPO_URL}.git" "$TTE_CC_HOME"
  fi
else
  echo "    git not found — downloading tarball"
  tmp="$(mktemp -d)"
  curl -fsSL "$TARBALL" | tar -xz -C "$tmp"
  rm -rf "$TTE_CC_HOME"
  mv "$tmp"/TTE_CC-* "$TTE_CC_HOME"
  rm -rf "$tmp"
fi

echo "==> Linking skills into: $SKILLS_DEST"
mkdir -p "$SKILLS_DEST"
linked=0
for d in "$TTE_CC_HOME"/.claude/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  name="$(basename "$d")"
  ln -sfn "$d" "$SKILLS_DEST/$name"
  echo "    + $name"
  linked=$((linked + 1))
done

echo
echo "Done. Linked $linked skill(s)."
echo "  Toolkit (R helpers, reference library, data): $TTE_CC_HOME"
echo "  Skills available in Claude Code, e.g.:  /target-trial"
echo
echo "Note: skills read the toolkit's reference/ and R/ files from \$TTE_CC_HOME"
echo "($TTE_CC_HOME). Generated analysis scripts set tte_root to that path."
