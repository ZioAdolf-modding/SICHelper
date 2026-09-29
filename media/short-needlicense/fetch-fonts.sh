#!/usr/bin/env bash
# Descarca fonturile folosite in animatie (nu sunt in repo): Inter, Rajdhani, Anton, Arimo, JetBrains Mono
# (Google Fonts, SIL OFL / Apache 2.0) si Font Awesome Free 6 Solid (SIL OFL 1.1).
set -euo pipefail
cd "$(dirname "$0")/assets"
mkdir -p fonts
: > fonts.css
for fam in "Rajdhani:wght@500;600;700" "Inter:wght@400;500;600;700;800" "Anton" "Arimo:wght@400;700" "JetBrains+Mono:wght@500;700"; do
  curl -sS "https://fonts.googleapis.com/css2?family=$fam" | python3 -c '
import re, sys, subprocess
for block in re.findall(r"@font-face\s*{[^}]*}", sys.stdin.read()):
    fam = re.search(r"font-family:\s*\x27([^\x27]+)\x27", block).group(1)
    w = re.search(r"font-weight:\s*(\d+)", block).group(1)
    url = re.search(r"url\(([^)]+)\)", block).group(1)
    fn = fam.replace(" ", "") + "-" + w + ".ttf"
    subprocess.run(["curl", "-sS", "-o", "fonts/" + fn, url], check=True)
    print("@font-face{font-family:\x27%s\x27;font-weight:%s;src:url(\x27fonts/%s\x27) format(\x27truetype\x27);}" % (fam, w, fn))
' >> fonts.css
done
tmp=$(mktemp -d)
(cd "$tmp" && npm pack @fortawesome/fontawesome-free@6.5.2 >/dev/null && tar xzf fortawesome-fontawesome-free-6.5.2.tgz)
cp "$tmp/package/webfonts/fa-solid-900.ttf" fonts/
rm -rf "$tmp"
echo "fonturile sunt in assets/fonts"
