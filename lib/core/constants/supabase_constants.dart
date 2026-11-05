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

final supabase = Supabase.instance.client;

