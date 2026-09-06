import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';

/// Kalıcı olay kuyruğunun sunucu seam'i.
abstract interface class TimesheetEventGateway {
  Future<WorkSession> send(TimesheetEvent event);

  Future<List<WorkSession>> fetchSessions(String assignmentId);
}

class AssignmentTimesheetEventGateway implements TimesheetEventGateway {
  AssignmentTimesheetEventGateway({AssignmentService? service})
    : _service = service ?? AssignmentService();

  final AssignmentService _service;

  @override
  Future<WorkSession> send(TimesheetEvent event) {
    final arguments = (
      assignmentId: event.assignmentId,
      latitude: event.latitude,
      longitude: event.longitude,
      clientEventId: event.clientEventId,
      capturedAt: event.capturedAt,
    );

    return switch (event.action) {
      TimesheetEventAction.checkIn => _service.checkIn(
        assignmentId: arguments.assignmentId,
        latitude: arguments.latitude,
        longitude: arguments.longitude,
        clientEventId: arguments.clientEventId,
        capturedAt: arguments.capturedAt,
      ),
      TimesheetEventAction.checkOut => _service.checkOut(
        assignmentId: arguments.assignmentId,
        latitude: arguments.latitude,
        longitude: arguments.longitude,
        clientEventId: arguments.clientEventId,
        capturedAt: arguments.capturedAt,
      ),
    };
  }

  @override
  Future<List<WorkSession>> fetchSessions(String assignmentId) {
    return _service.fetchWorkSessions(assignmentId);
  }
}
