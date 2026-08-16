#!/usr/bin/env bash
set -euo pipefail

echo "Installing Flutter SDK..."
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
fi

export PATH="$HOME/flutter/bin:$HOME/flutter/bin/cache/dart-sdk/bin:$PATH"

flutter --version
flutter precache --web

if [ -n "${SUPABASE_URL:-}" ] || [ -n "${SUPABASE_KEY:-}" ]; then
  printf 'SUPABASE_URL=%s\nSUPABASE_KEY=%s\n' "${SUPABASE_URL:-}" "${SUPABASE_KEY:-}" > .env
else
  echo "No Render env vars found. Creating empty .env file."
  : > .env
fi

flutter pub get
flutter build web --release

echo "Build completed successfully."
