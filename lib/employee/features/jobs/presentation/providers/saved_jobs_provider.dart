import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job.dart';

class SavedJobsProvider extends ChangeNotifier {
  final List<Job> _savedJobs = [];

  List<Job> get savedJobs => List.unmodifiable(_savedJobs);

  bool isSaved(String jobId) {
    return _savedJobs.any((job) => job.id == jobId);
  }

  void toggleSave(Job job) {
    final index = _savedJobs.indexWhere((j) => j.id == job.id);
    if (index != -1) {
      _savedJobs.removeAt(index);
    } else {
      _savedJobs.add(job);
    }
    notifyListeners();
  }

  void removeJob(String jobId) {
    _savedJobs.removeWhere((job) => job.id == jobId);
    notifyListeners();
  }
}
