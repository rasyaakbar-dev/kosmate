import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/complaint_service.dart';
import '../../services/house_service.dart';
import '../../services/midtrans_service.dart';
import '../../services/payment_service.dart';
import '../../services/room_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';

/// A simple, manually-wired service locator (singleton registry).
///
/// Call [ServiceLocator.instance.setup()] once in [main] after Supabase
/// is initialized. Access services anywhere via the [sl] top-level getter.
///
/// Example:
/// ```dart
/// final houses = await sl.house.getHousesByOwner(userId);
/// ```
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  late final AuthService auth;
  late final UserService user;
  late final HouseService house;
  late final RoomService room;
  late final BookingService booking;
  late final PaymentService payment;
  late final ComplaintService complaint;
  late final StorageService storage;
  late final MidtransService midtrans;

  /// Wire up all services. Must be called once after [Supabase.initialize].
  void setup() {
    auth = AuthService();
    user = UserService(auth);
    house = HouseService();
    room = RoomService();
    booking = BookingService();
    payment = PaymentService();
    complaint = ComplaintService();
    storage = StorageService();
    midtrans = MidtransService();
  }
}

/// Convenience top-level accessor: `sl.house`, `sl.auth`, etc.
ServiceLocator get sl => ServiceLocator.instance;
