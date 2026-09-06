import 'package:koala/employee/features/profile/models/availability_exception.dart';
import 'package:koala/employee/features/profile/models/availability_slot.dart';

/// Bir kullanıcının haftalık şablonu ve yaklaşan tarih istisnaları.
class Availability {
  Availability({
    required List<AvailabilitySlot> slots,
    required List<AvailabilityException> exceptions,
  }) : slots = List.unmodifiable(slots),
       exceptions = List.unmodifiable(exceptions);

  final List<AvailabilitySlot> slots;
  final List<AvailabilityException> exceptions;

  factory Availability.fromJson(Map<String, dynamic> json) {
    final slots = json['slots'] as List<dynamic>? ?? const [];
    final exceptions = json['exceptions'] as List<dynamic>? ?? const [];

    return Availability(
      slots: slots
          .map(
            (item) => AvailabilitySlot.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      exceptions: exceptions
          .map(
            (item) =>
                AvailabilityException.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  bool get isEmpty => slots.isEmpty && exceptions.isEmpty;
}
