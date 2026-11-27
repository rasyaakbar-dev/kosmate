import 'package:flutter_test/flutter_test.dart';
import 'package:kosmate/models/complaint_model.dart';

void main() {
  ComplaintModel complaintWithStatus(ComplaintStatus status) {
    return ComplaintModel(
      complaintId: 1,
      userId: 1,
      roomId: 1,
      category: ComplaintCategory.maintenance,
      title: 'Leaking tap',
      description: 'The tap is leaking.',
      priority: ComplaintPriority.medium,
      date: DateTime(2026, 11, 27),
      status: status,
    );
  }

  test('tenants can delete pending and rejected complaints', () {
    expect(
      complaintWithStatus(ComplaintStatus.pending).canBeDeletedByTenant,
      isTrue,
    );
    expect(
      complaintWithStatus(ComplaintStatus.rejected).canBeDeletedByTenant,
      isTrue,
    );
  });

  test('tenants cannot delete in-progress or resolved complaints', () {
    expect(
      complaintWithStatus(ComplaintStatus.inProgress).canBeDeletedByTenant,
      isFalse,
    );
    expect(
      complaintWithStatus(ComplaintStatus.resolved).canBeDeletedByTenant,
      isFalse,
    );
  });
}
