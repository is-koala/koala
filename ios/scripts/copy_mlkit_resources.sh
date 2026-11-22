#!/bin/sh
# Xcode "Copy ML Kit Resources" build phase.
#
# google_mlkit_text_recognition SPM'den geliyor ve Package.swift'i
# LatinOCRResources.bundle'ı kaynak olarak tanımlamıyor; bundle uygulamaya
# girmezse ML Kit modeli bulamaz ve iOS'ta MRZ okuması çalışmaz. Bundle'ı
# eklentinin kendi kopyasından alıyoruz ki eklenti yükselince model de
# kendiliğinden güncellensin.
set -eu

package_config="${SRCROOT}/../.dart_tool/package_config.json"
if [ ! -f "$package_config" ]; then
  echo "error: ${package_config} yok; önce flutter pub get çalıştırın." >&2
  exit 1
fi

root_uri=$(/usr/bin/python3 -c '
import json, sys
for p in json.load(open(sys.argv[1]))["packages"]:
    if p["name"] == "google_mlkit_text_recognition":
        print(p["rootUri"])
' "$package_config")

if [ -z "$root_uri" ]; then
  echo "error: google_mlkit_text_recognition package_config.json'da bulunamadı." >&2
  exit 1
fi

case "$root_uri" in
  file://*) package_root="${root_uri#file://}" ;;
  *) package_root="${SRCROOT}/../.dart_tool/${root_uri}" ;;
esac

bundle="${package_root}/ios/google_mlkit_text_recognition/Sources/google_mlkit_text_recognition/LatinOCRResources.bundle"
if [ ! -d "$bundle" ]; then
  echo "error: ${bundle} yok; eklentinin dizin yapısı değişmiş olabilir." >&2
  exit 1
fi

destination="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "$destination"
rsync -a --delete "$bundle" "$destination/"
