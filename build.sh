#!/bin/bash

# Exit on error
set -e

echo "--- Checking Flutter SDK ---"
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter stable..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
else
  echo "Flutter already exists, updating..."
  cd flutter && git pull && cd ..
fi

# Add flutter to path
export PATH="$PATH:$(pwd)/flutter/bin"

echo "--- Flutter Version ---"
flutter --version

echo "--- Enabling Web Support ---"
flutter config --enable-web

echo "--- Getting Dependencies ---"
flutter pub get

echo "--- Building Web Release ---"
flutter build web --release --base-href "/"

echo "--- Build Finished ---"
