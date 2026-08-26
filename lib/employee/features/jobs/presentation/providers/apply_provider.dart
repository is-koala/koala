import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';

class ApplyProvider extends ChangeNotifier {
  final List<MyJob> _appliedJobs = [];

  List<MyJob> get appliedJobs => List.unmodifiable(_appliedJobs);

  bool hasApplied(String jobId) {
    return _appliedJobs.any((job) => job.id == 'applied_$jobId');
  }

  void applyToJob(Job job, {String? coverLetter}) {
    if (hasApplied(job.id)) return;

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    final myJob = MyJob(
      id: 'applied_${job.id}',
      title: job.title,
      company: job.company ?? 'Bilinmeyen Şirket',
      companyId: job.companyDetails?.id,
      description: job.description ?? job.subtitle,
      date: dateStr,
      price: job.price,
      status: MyJobStatus.pending,
    );

    _appliedJobs.insert(0, myJob);
    notifyListeners();
  }
}
