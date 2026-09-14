#!/bin/sh
# Xcode "Check Maps API Key" build phase (is-koala/koala#172).
#
# MAPS_API_KEY, flavor xcconfig'inin include ettiği gitignore'lu
# ios/Flutter/Secrets.<flavor>.xcconfig dosyasından gelir ve Info.plist'e
# $(MAPS_API_KEY) olarak girer. Boşsa AppDelegate Maps SDK'sına anahtar
# vermez; uygulama çökmez ama harita ekranları yer tutucu gösterir. Bu betik
# derlemeyi kırmaz, yalnız bir kez `warning:` yazar ki eksik anahtar Xcode ve
# `flutter build ios` çıktısında görünür olsun. Anahtarın değeri asla
# yazılmaz.
set -eu

if [ -n "${MAPS_API_KEY:-}" ]; then
  exit 0
fi

flavor="${CONFIGURATION#*-}"
case "$flavor" in
  dev|staging|production) secrets="ios/Flutter/Secrets.${flavor}.xcconfig" ;;
  *) secrets="ios/Flutter/Secrets.<flavor>.xcconfig" ;;
esac

echo "warning: MAPS_API_KEY boş (${CONFIGURATION:-?}). ${secrets} dosyası yok ya da anahtar yazılmamış; harita ekranları bu derlemede yer tutucu gösterir. Bkz. docs/ios-maps-api-key.md"
exit 0
