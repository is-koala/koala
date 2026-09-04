# Mobil ortamlar için ayrı uygulama kimlikleri kullan

Koala'nın production, staging ve development yapıları sırasıyla `com.iskoala.koala`, `com.iskoala.koala.staging` ve `com.iskoala.koala.dev` kimliklerini kullanacaktır. Ayrı kimlikler uygulamaların aynı cihazda birlikte bulunmasını, Maps anahtarlarının ve deep-link yetkilerinin ortam bazında kısıtlanmasını ve bir test build'inin production uygulamasının verisini veya oturumunu ezmemesini sağlar. Mağaza kimliği yayımlandıktan sonra değiştirmek maliyetli olduğu için tek bundle ID ile sunucu değiştirme yaklaşımı reddedilmiştir.

Q35-A uyarınca bugün iki simülatörde `staging` yapısı mevcut `https://api.iskoala.com` adresini kullanır; `dev` açıkça yapılandırılan yerel Koala backend'e bağlanır. Production sürümü lansmana kadar yayımlanmaz. API hedefi veya ortam seçimi eksikse uygulama sessizce mevcut internet API'sine dönmez.
