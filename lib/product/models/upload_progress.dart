/// Gönderilen baytın 0-1 oranı; toplam bilinmiyorsa (`<= 0`, dio geçici olarak
/// `-1` verebiliyor) `null` ve çubuk belirsiz.
double? uploadFraction(int sent, int total) =>
    total <= 0 ? null : (sent / total).clamp(0.0, 1.0);
