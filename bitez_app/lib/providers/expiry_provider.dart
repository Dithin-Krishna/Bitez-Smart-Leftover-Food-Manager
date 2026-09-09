import 'package:flutter/material.dart';
import '../models/fridge_item_model.dart';
import '../services/expiry_service.dart';
import '../services/fridge_service.dart';
import '../services/local_notification_service.dart';

class ExpiryProvider extends ChangeNotifier {
  List<FridgeItemModel> _items = [];
  ExpirySummaryData? _summary;
  bool _isLoading = false;
  String _activeFilter = 'all'; // 'all', 'expiringSoon', 'expired', 'fresh'
  String? _errorMessage;

  List<FridgeItemModel> get items => _items;
  ExpirySummaryData? get summary => _summary;
  bool get isLoading => _isLoading;
  String get activeFilter => _activeFilter;
  String? get errorMessage => _errorMessage;

  int get expiredCount => _items.where((i) => i.expiryStatus == ExpiryStatus.expired).length;
  int get expiringSoonCount => _items.where((i) => i.expiryStatus == ExpiryStatus.expiringSoon).length;
  int get freshCount => _items.where((i) => i.expiryStatus == ExpiryStatus.fresh).length;
  int get untrackedCount => _items.where((i) => i.expiryStatus == ExpiryStatus.untracked).length;

  bool get hasUrgentAlerts => expiredCount > 0 || expiringSoonCount > 0;

  List<FridgeItemModel> get filteredItems {
    switch (_activeFilter) {
      case 'expired':
        return _items.where((i) => i.expiryStatus == ExpiryStatus.expired).toList();
      case 'expiringSoon':
        return _items.where((i) => i.expiryStatus == ExpiryStatus.expiringSoon).toList();
      case 'fresh':
        return _items.where((i) => i.expiryStatus == ExpiryStatus.fresh).toList();
      case 'all':
      default:
        // Prioritize items with expiry set, sorted by days remaining
        final tracked = _items.where((i) => i.expiresAt != null).toList()
          ..sort((a, b) => (a.daysRemaining ?? 999).compareTo(b.daysRemaining ?? 999));
        final untracked = _items.where((i) => i.expiresAt == null).toList();
        return [...tracked, ...untracked];
    }
  }

  void setFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  Future<void> fetchExpiryData(String? token) async {
    if (token == null || token.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch all fridge items so users can add/track expiry for any item
      final rawItems = await FridgeService.instance.getAllItems(token: token);
      _items = rawItems.map((map) => FridgeItemModel.fromJson(map)).toList();

      _summary = await ExpiryService.instance.fetchExpirySummary(token: token);
      
      // Trigger native phone notification bar alert if items are expiring
      if (hasUrgentAlerts) {
        final count = expiredCount + expiringSoonCount;
        LocalNotificationService.instance.showExpiryNotification(
          id: 101,
          title: '⚠️ Bitez Food Expiry Alert',
          body: expiredCount > 0
              ? '$expiredCount item(s) expired, $expiringSoonCount expiring soon in your fridge!'
              : '$expiringSoonCount item(s) in your fridge expire within 48 hours!',
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateItemExpiry({
    required String? token,
    required String itemId,
    DateTime? expiresAt,
    DateTime? manufacturingDate,
    String? expiryImage,
    String? expiryNotes,
  }) async {
    if (token == null) return false;

    try {
      final updated = await ExpiryService.instance.updateItemExpiry(
        token: token,
        itemId: itemId,
        expiresAt: expiresAt,
        manufacturingDate: manufacturingDate,
        expiryImage: expiryImage,
        expiryNotes: expiryNotes,
      );

      final index = _items.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        _items[index] = updated;
      } else {
        _items.add(updated);
      }

      await fetchExpiryData(token);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(String? token, String itemId) async {
    if (token == null) return false;
    try {
      await FridgeService.instance.deleteItem(token: token, id: itemId);
      _items.removeWhere((i) => i.id == itemId);
      await fetchExpiryData(token);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
