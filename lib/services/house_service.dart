import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/json_helpers.dart';
import '../models/house_model.dart';

class HouseService {
  final SupabaseClient _client;

  static const String _selectWithOwner = '*, users!house_owner_id_fkey(*)';

  HouseService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  Future<List<HouseModel>> getAllHouses() async {
    try {
      final response = await _client
          .from(SupabaseConstants.houseTable)
          .select(_selectWithOwner)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(HouseModel.fromJson);
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to load houses.', code: e.code, cause: e);
    } catch (e) {
      throw ServiceException('Failed to load houses.', cause: e);
    }
  }

  Future<List<HouseModel>> getHousesByOwner(int ownerId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.houseTable)
          .select(_selectWithOwner)
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(HouseModel.fromJson);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load your houses.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load your houses.', cause: e);
    }
  }

  Future<HouseModel?> getHouseById(int houseId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.houseTable)
          .select(_selectWithOwner)
          .eq('house_id', houseId)
          .maybeSingle();

      if (response == null) return null;
      return HouseModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load house details.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load house details.', cause: e);
    }
  }

  Future<HouseModel> createHouse(HouseModel house) async {
    try {
      final response = await _client
          .from(SupabaseConstants.houseTable)
          .insert(house.toJson(includeId: false))
          .select(_selectWithOwner)
          .single();

      return HouseModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to create house.', code: e.code, cause: e);
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
          .select(_selectWithOwner)
          .single();

      return HouseModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to update house.', code: e.code, cause: e);
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
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to delete house.', code: e.code, cause: e);
    } catch (e) {
      throw ServiceException('Failed to delete house.', cause: e);
    }
  }
}
