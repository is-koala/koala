/// Gönderilen bayt sayısının 0-1 arası oranı; toplam henüz bilinmiyorsa
/// (`total <= 0`) `null` — çubuk belirsiz (dönen) kalıyor.
///
/// Kimlik fotoğrafı ve kanıt yüklemesinin ilerleme çubuğu aynı hesabı
/// yapıyor; dio gönderim sırasında toplamı geçici olarak `-1` verebiliyor.
double? uploadFraction(int sent, int total) =>
    total <= 0 ? null : (sent / total).clamp(0.0, 1.0);
