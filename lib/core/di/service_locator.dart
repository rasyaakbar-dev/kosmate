import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/complaint_service.dart';
import '../../services/house_service.dart';
import '../../services/midtrans_service.dart';
import '../../services/payment_service.dart';
import '../../services/room_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';

class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  late AuthService auth;
  late UserService user;
  late HouseService house;
  late RoomService room;
  late BookingService booking;
  late PaymentService payment;
  late ComplaintService complaint;
  late StorageService storage;
  late MidtransService midtrans;

  void setup([SupabaseClient? client]) {
    final supabaseClient = client ?? Supabase.instance.client;
    auth = AuthService(supabaseClient);
    user = UserService(auth, supabaseClient);
    house = HouseService(supabaseClient);
    room = RoomService(supabaseClient);
    booking = BookingService(supabaseClient);
    midtrans = MidtransService(supabaseClient);
    payment = PaymentService(midtrans, supabaseClient);
    complaint = ComplaintService(supabaseClient);
    storage = StorageService(supabaseClient);
  }
}

ServiceLocator get sl => ServiceLocator.instance;
