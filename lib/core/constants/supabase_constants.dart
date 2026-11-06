import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConstants {
  static const String supabaseUrl = 'https://mojbiwkvxanpkpzvamnh.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_x-U2wU3iW7Z7YZyND2-E0g_tW-uwkfz';

  // Table names
  static const String usersTable = 'users';
  static const String houseTable = 'house';
  static const String roomTable = 'room';
  static const String bookingTable = 'booking';
  static const String paymentTable = 'payment';
  static const String complaintTable = 'complaint';

  // Storage Buckets
  static const String roomImagesBucket = 'room-images';
  static const String paymentReceiptsBucket = 'payment-receipts';
  static const String complaintAttachmentsBucket = 'complaint-attachments';
}

class MidtransConstants {
  static const bool isProduction = false;
  static const String sandboxBaseUrl = 'https://api.sandbox.midtrans.com/v2';
  static const String productionBaseUrl = 'https://api.midtrans.com/v2';

  /// Midtrans Sandbox Server Key (configured for testing)
  static const String serverKey = 'SB-Mid-server-YOUR_SERVER_KEY_HERE';
  static const String clientKey = 'SB-Mid-client-YOUR_CLIENT_KEY_HERE';

  static String get baseUrl => isProduction ? productionBaseUrl : sandboxBaseUrl;
}

final supabase = Supabase.instance.client;

