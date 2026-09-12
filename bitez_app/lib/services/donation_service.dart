import 'package:flutter/foundation.dart';
import '../models/ngo_model.dart';
import 'api_service.dart';

import '../models/sync_operation.dart';
import 'offline_storage_service.dart';
import 'sync_service.dart';

/// Service managing Community Food Banks directory and donation pledge routing.
class DonationService {
  DonationService._();
  static final DonationService instance = DonationService._();

  /// Reactive notifier triggered whenever a donation pledge changes.
  final ValueNotifier<int> donationUpdatedNotifier = ValueNotifier<int>(0);

  /// Fetch list of verified community Food Banks & NGOs
  Future<List<NgoModel>> getNgos(String token) async {
    try {
      final res = await ApiService.instance.get('/api/donations/ngos', token: token);
      final raw = res['ngos'] as List<dynamic>? ?? [];
      final ngosMap = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await OfflineStorageService.instance.cacheNgoList(ngosMap);
      return ngosMap.map(NgoModel.fromJson).toList();
    } catch (e) {
      debugPrint('DonationService.getNgos error: $e');
      final cached = OfflineStorageService.instance.getCachedNgoList();
      if (cached != null && cached.isNotEmpty) {
        return cached.map(NgoModel.fromJson).toList();
      }
      return _fallbackNgos;
    }
  }

  /// Assign a pledged food item to an NGO center
  Future<bool> assignPledge({
    required String token,
    required String itemId,
    required String ngoName,
    String? notes,
  }) async {
    final payload = {
      'itemId': itemId,
      'ngoName': ngoName,
      'notes': ?notes,
    };

    try {
      final res = await ApiService.instance.post(
        '/api/donations/assign',
        payload,
        token: token,
      );

      if (res['success'] == true) {
        donationUpdatedNotifier.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('DonationService.assignPledge offline: $e. Queuing sync mutation.');
      await SyncService.instance.queueMutation(
        type: SyncOpType.assignDonation,
        payload: payload,
      );
      donationUpdatedNotifier.value++;
      return true;
    }
  }

  static final List<NgoModel> _fallbackNgos = [
    const NgoModel(
      id: 'ngo_fb_1',
      name: 'Annam Food Bank & Rescue',
      type: 'Food Bank',
      description: 'Collecting surplus cooked meals and fresh produce for underprivileged families.',
      phone: '+91 98470 12345',
      email: 'contact@annamfoodrescue.org',
      address: 'Near Town Hall, Marine Drive, Kochi',
      city: 'Kochi',
      operatingHours: '8:00 AM - 8:00 PM (Daily)',
      acceptedItems: ['Cooked Meals', 'Fresh Produce', 'Packaged Food', 'Dairy & Eggs'],
      isVerified: true,
      distanceKm: 1.8,
    ),
    const NgoModel(
      id: 'ngo_fb_2',
      name: 'Robin Hood Army Kochi',
      type: 'NGO / Rescue',
      description: 'Zero-funds volunteer organization routing surplus food from households to local shelters.',
      phone: '+91 94471 67890',
      email: 'kochi@robinhoodarmy.com',
      address: 'Kaloor Junction, Kochi',
      city: 'Kochi',
      operatingHours: '10:00 AM - 9:00 PM',
      acceptedItems: ['Cooked Meals', 'Bakery', 'Fruits & Vegetables'],
      isVerified: true,
      distanceKm: 3.2,
    ),
    const NgoModel(
      id: 'ngo_fb_3',
      name: 'Janakeeya Community Fridge',
      type: 'Community Fridge',
      description: 'Public 24/7 refrigerator where neighbors drop off safe leftover food and produce.',
      phone: '+91 484 2398765',
      email: 'support@janakeeyafridge.org',
      address: 'MG Road, Opposite Medical Trust, Ernakulam',
      city: 'Kochi',
      operatingHours: 'Open 24 Hours',
      acceptedItems: ['Fresh Produce', 'Packaged Food', 'Bakery', 'Bottled Drinks'],
      isVerified: true,
      distanceKm: 4.1,
    ),
    const NgoModel(
      id: 'ngo_fb_4',
      name: 'Asha Bhavan Care Shelter',
      type: 'Shelter & Kitchen',
      description: 'Community home providing daily hot meals to elders and destitute residents.',
      phone: '+91 98950 43210',
      email: 'ashabhavan.trust@gmail.com',
      address: 'Thrikkakara, Near Model Engineering College, Kakkanad',
      city: 'Kochi',
      operatingHours: '9:00 AM - 6:00 PM',
      acceptedItems: ['Cooked Meals', 'Rice & Grains', 'Fresh Produce'],
      isVerified: true,
      distanceKm: 5.4,
    ),
    const NgoModel(
      id: 'ngo_fb_5',
      name: 'No Food Waste India (Kerala)',
      type: 'NGO / Rescue',
      description: 'Food recovery network with dedicated pickup transport for quantities over 5kg.',
      phone: '+91 90877 90877',
      email: 'info@nofoodwaste.in',
      address: 'Palarivattom Bypass Junction, Kochi',
      city: 'Kochi',
      operatingHours: '9:00 AM - 10:00 PM',
      acceptedItems: ['Cooked Meals', 'Excess Catering', 'Bakery', 'Packaged Food'],
      isVerified: true,
      distanceKm: 6.0,
    ),
  ];
}
