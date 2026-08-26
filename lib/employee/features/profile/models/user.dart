class User {
  String fullName;
  String jobTitle;
  String location;
  String about;
  String cvFileName;
  String profileImage;
  List<Experience> experiences;

  User({
    required this.fullName,
    required this.jobTitle,
    required this.location,
    required this.about,
    required this.cvFileName,
    required this.profileImage,
    required this.experiences,
  });

  User copyWith({
    String? fullName,
    String? jobTitle,
    String? location,
    String? about,
    String? cvFileName,
    String? profileImage,
    List<Experience>? experiences,
  }) {
    return User(
      fullName: fullName ?? this.fullName,
      jobTitle: jobTitle ?? this.jobTitle,
      location: location ?? this.location,
      about: about ?? this.about,
      cvFileName: cvFileName ?? this.cvFileName,
      profileImage: profileImage ?? this.profileImage,
      experiences: experiences ?? this.experiences,
    );
  }
}

class Experience {
  String title;
  String company;
  String duration;
  String description;

  Experience({
    required this.title,
    required this.company,
    required this.duration,
    required this.description,
  });
}
