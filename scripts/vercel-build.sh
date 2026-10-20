#!/usr/bin/env bash
set -Eeuo pipefail

echo "=================================================="
echo " ArvaLink Web Production Build (Vercel)"
echo "=================================================="

# Allow git operations in Vercel root container
git config --global --add safe.directory '*' 2>/dev/null || true

FLUTTER_VERSION="3.44.8"
FLUTTER_DIR="${HOME}/flutter-sdk-${FLUTTER_VERSION}"

if command -v flutter >/dev/null 2>&1; then
  echo "Found Flutter on system PATH: $(flutter --version | head -n 1)"
elif [ -d "${FLUTTER_DIR}/bin" ]; then
  echo "Using cached Flutter SDK at ${FLUTTER_DIR}"
  export PATH="${FLUTTER_DIR}/bin:${PATH}"
else
  echo "Downloading pinned Flutter SDK ${FLUTTER_VERSION}..."
  mkdir -p "${FLUTTER_DIR}"
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" | tar -xJ -C "${FLUTTER_DIR}" --strip-components=1
  export PATH="${FLUTTER_DIR}/bin:${PATH}"
fi

echo "Verifying Flutter runtime:"
flutter --version

flutter config --no-analytics
flutter pub get
echo "Executing release Web compilation..."
flutter build web --release

echo "==> ArvaLink Web release generated in build/web"
