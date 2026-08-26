import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/business/features/home/models/b_applicant.dart';

/// İşveren tarafında iş ilanı + başvuranlar modeli
class BJobPost {
  final Job job;
  final bool isActive;
  final List<BApplicant> applicants;
  final BApplicant? worker;
  final DateTime createdAt;

  const BJobPost({
    required this.job,
    required this.isActive,
    this.applicants = const [],
    this.worker,
    required this.createdAt,
  });

  BJobPost copyWith({
    Job? job,
    bool? isActive,
    List<BApplicant>? applicants,
    BApplicant? worker,
    DateTime? createdAt,
  }) {
    return BJobPost(
      job: job ?? this.job,
      isActive: isActive ?? this.isActive,
      applicants: applicants ?? this.applicants,
      worker: worker ?? this.worker,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
