#!/usr/bin/env bash
# Downloads the freely licensed (SIL OFL) fonts used by the exploration renders.
# Fonts come from the @fontsource npm packages (same files as Google Fonts).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)/fonts"
mkdir -p "$DIR" && cd "$DIR"
for p in grenze-gotisch grenze alegreya-sans uncial-antiqua alegreya nunito cinzel-decorative cinzel signika im-fell-english-sc im-fell-english eb-garamond bree-serif source-sans-3 caveat architects-daughter patrick-hand kalam fondamento amatic-sc shantell-sans; do
  npm pack "@fontsource/$p" --silent >/dev/null
done
for f in *.tgz; do mkdir -p tmp && tar xzf "$f" -C tmp && cp tmp/package/files/*-latin-[0-9]*-normal.woff2 tmp/package/files/*-latin-[0-9]*-italic.woff2 . 2>/dev/null || true; rm -rf tmp "$f"; done
ls "$DIR" | wc -l
