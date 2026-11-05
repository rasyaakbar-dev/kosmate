import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/house_model.dart';

class HouseService {
  final SupabaseClient _client = supabase;

  /// Fetch all boarding houses with owner information
  Future<List<HouseModel>> getAllHouses() async {
    final response = await _client
        .from(SupabaseConstants.houseTable)
        .select('*, users!house_owner_id_fkey(*)')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => HouseModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch houses owned by a specific owner
  Future<List<HouseModel>> getHousesByOwner(int ownerId) async {
    final response = await _client
        .from(SupabaseConstants.houseTable)
        .select('*, users!house_owner_id_fkey(*)')
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => HouseModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch single house by ID
  Future<HouseModel?> getHouseById(int houseId) async {
    final response = await _client
        .from(SupabaseConstants.houseTable)
        .select('*, users!house_owner_id_fkey(*)')
        .eq('house_id', houseId)
        .maybeSingle();

    if (response == null) return null;
    return HouseModel.fromJson(response);
  }

  /// Create a new boarding house
  Future<HouseModel> createHouse(HouseModel house) async {
    final response = await _client
        .from(SupabaseConstants.houseTable)
        .insert(house.toJson(includeId: false))
        .select('*, users!house_owner_id_fkey(*)')
        .single();

    return HouseModel.fromJson(response);
  }

  /// Update an existing house
  Future<HouseModel> updateHouse(HouseModel house) async {
    final response = await _client
        .from(SupabaseConstants.houseTable)
        .update(house.toJson(includeId: false))
        .eq('house_id', house.houseId)
        .select('*, users!house_owner_id_fkey(*)')
        .single();

    return HouseModel.fromJson(response);
  }

  /// Delete a house
  Future<void> deleteHouse(int houseId) async {
    await _client
        .from(SupabaseConstants.houseTable)
        .delete()
        .eq('house_id', houseId);
  }
}

