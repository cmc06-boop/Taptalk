import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/auth_validation.dart';
import '../data/models/saved_account.dart';

class SavedAccountsStore {
  static const _prefsKey = 'taptalk_saved_accounts';
  static const maxAccounts = 5;

  Future<List<SavedAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final accounts = decoded
          .whereType<Map>()
          .map((e) => SavedAccount.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.email.isNotEmpty)
          .toList();
      accounts.sort((a, b) => b.lastUsedAtMs.compareTo(a.lastUsedAtMs));
      return accounts;
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(SavedAccount account) async {
    final email = AuthValidation.normalizeEmail(account.email);
    if (email.isEmpty) return;

    final accounts = await load();
    final updated = SavedAccount(
      email: email,
      displayName: account.displayName,
      role: account.role,
      lastUsedAtMs: DateTime.now().millisecondsSinceEpoch,
      firebaseUid: account.firebaseUid,
    );
    final next = [
      updated,
      ...accounts.where((a) => a.email != email),
    ].take(maxAccounts).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(next.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> remove(String email) async {
    final normalized = AuthValidation.normalizeEmail(email);
    if (normalized.isEmpty) return;
    final next = [
      for (final account in await load())
        if (account.email != normalized) account,
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(next.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
