#!/usr/bin/env bash
# Compila la web y la APK de Android y publica ambas en Firebase Hosting.
# La APK queda en https://pasaportemisionerovirtual.web.app/descargar/PasaporteCMO.apk
# (siempre el mismo enlace; cada publicación lo actualiza).
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build apk --release
flutter build web --release

mkdir -p build/web/descargar
cp build/app/outputs/flutter-apk/app-release.apk build/web/descargar/PasaporteCMO.apk

firebase deploy --only hosting
