import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/supabase_helpers.dart';
import '../models/house_model.dart';

class HouseService {
  final SupabaseClient _client = supabase;

  Future<List<HouseModel>> getAllHouses() async {
    try {
      final response = await _client
          .from(SupabaseConstants.houseTable)
          .select('*, users!house_owner_id_fkey(*)')
          .order('created_at', ascending: false);

      return (response as List).mapToModel(HouseModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load houses.', cause: e);
    }
  }

  Future<List<HouseModel>> getHousesByOwner(int ownerId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.houseTable)
          .select('*, users!house_owner_id_fkey(*)')
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(HouseModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load your houses.', cause: e);
    }
  }

  Future<HouseModel?> getHouseById(int houseId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.houseTable)
          .select('*, users!house_owner_id_fkey(*)')
          .eq('house_id', houseId)
          .maybeSingle();

      if (response == null) return null;
      return HouseModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to load house details.', cause: e);
    }
  }

  Future<HouseModel> createHouse(HouseModel house) async {
    try {
      final response = await _client
          .from(SupabaseConstants.houseTable)
          .insert(house.toJson(includeId: false))
          .select('*, users!house_owner_id_fkey(*)')
          .single();

      return HouseModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to create house.', cause: e);
    }
  }

  Future<HouseModel> updateHouse(HouseModel house) async {
    try {
      final response = await _client
          .from(SupabaseConstants.houseTable)
          .update(house.toJson(includeId: false))
          .eq('house_id', house.houseId)
          .select('*, users!house_owner_id_fkey(*)')
          .single();

      return HouseModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to update house.', cause: e);
    }
  }

  Future<void> deleteHouse(int houseId) async {
    try {
      await _client
          .from(SupabaseConstants.houseTable)
          .delete()
          .eq('house_id', houseId);
    } catch (e) {
      throw ServiceException('Failed to delete house.', cause: e);
    }
  }
}
