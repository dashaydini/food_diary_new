#!/usr/bin/env bash
set -e

# Usage: ./scripts/generate_icons.sh
# Converts assets/logo/bite_the_way_logo.svg -> assets/logo/icon.png (1024x1024)
# then runs flutter_launcher_icons to generate platform icons.

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$PROJECT_ROOT/assets/logo/bite_the_way_logo.svg"
ICON_PNG="$PROJECT_ROOT/assets/logo/icon.png"

if [ ! -f "$SVG" ]; then
  echo "SVG not found: $SVG"
  exit 1
fi

# Try rsvg-convert (librsvg)
if command -v rsvg-convert >/dev/null 2>&1; then
  echo "Converting SVG -> PNG using rsvg-convert..."
  rsvg-convert -w 1024 -h 1024 "$SVG" -o "$ICON_PNG"

# Try inkscape
elif command -v inkscape >/dev/null 2>&1; then
  echo "Converting SVG -> PNG using inkscape..."
  inkscape "$SVG" --export-type=png --export-filename="$ICON_PNG" --export-width=1024 --export-height=1024

else
  echo "No SVG converter found. Please install 'rsvg-convert' (librsvg) or 'inkscape', or provide a PNG named assets/logo/icon.png (1024x1024)."
  exit 1
fi

# Install deps and run flutter_launcher_icons
echo "Running flutter pub get..."
flutter pub get

echo "Generating launcher icons..."
flutter pub run flutter_launcher_icons:main

echo "Done. Check Android mipmap and iOS AppIcon assets." 
