import 'package:koala/employee/features/profile/models/user.dart';

class FakeUser {
  static final User instance = User(
    fullName: "Yakup Demir",
    jobTitle: "Fotoğrafçı",
    location: "Küçükçekmece/İstanbul",
    about:
        "Profesyonel etkinlik ve ürün fotoğrafçısıyım. Yüksek kaliteli ekipman ve hızlı teslimat garantisiyle çalışıyorum. İşlerinize değer katacak profesyonel kareler için profili inceleyebilir, hemen iletişime geçebilirsiniz.",
    cvFileName: "yakup_demir_cv.pdf",
    profileImage: "assets/images/koala_profile_picture.png",
    experiences: [
      Experience(
        title: "Kıdemli Fotoğrafçı",
        company: "Studio Kreatif",
        duration: "Ocak 2023 - Halen",
        description:
            "Kurumsal etkinlik ve ürün fotoğrafçılığı. Haftalık ortalama 5 etkinlik çekimi.",
      ),
      Experience(
        title: "Fotoğrafçı",
        company: "EventShot Medya",
        duration: "Mart 2021 - Aralık 2022",
        description:
            "Düğün, nişan ve özel gün fotoğrafçılığı. 200+ etkinlikte görev aldım.",
      ),
      Experience(
        title: "Stajyer Fotoğrafçı",
        company: "Lens Ajans",
        duration: "Haziran 2020 - Şubat 2021",
        description:
            "Stüdyo çekimleri, ışık düzeni kurulumu ve post-prodüksiyon süreçlerinde destek.",
      ),
      Experience(
        title: "Freelance Fotoğrafçı",
        company: "Serbest",
        duration: "Ocak 2019 - Mayıs 2020",
        description:
            "Sosyal medya içerik üretimi, portre ve doğa fotoğrafçılığı. 50+ müşteri portföyü.",
      ),
    ],
  );
}
