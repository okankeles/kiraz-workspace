import 'lease.dart';
import 'rent_period.dart';

class PendingApprovalItem {
  final RentPeriod period;
  final Lease lease;

  PendingApprovalItem({
    required this.period,
    required this.lease,
  });

  String get propertyName =>
      (lease.propertyName != null && lease.propertyName!.isNotEmpty)
          ? lease.propertyName!
          : 'Taşınmaz #${lease.propertyId}';

  String get tenantName =>
      (lease.tenantName != null && lease.tenantName!.isNotEmpty)
          ? lease.tenantName!
          : 'Kiracı';

  double get amount => lease.rentAmount;
}
