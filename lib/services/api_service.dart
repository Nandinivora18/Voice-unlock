// api_service.dart
// All HTTP calls to the local Python Flask backend.
// The session token (received after a successful /verify) must be
// passed to every vault CRUD endpoint via the X-Session-Token header.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ApiService {
  ApiService._();

  static String get _base => AppConstants.serverUrl;

  // ── Convenience helpers ────────────────────────────────────────────

  static Map<String, String> _authHeader(String token) =>
      {AppConstants.sessionHeader: token};

  static Map<String, dynamic>? _parseBody(http.Response res) {
    try {
      return json.decode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Status ─────────────────────────────────────────────────────────

  /// Returns {enrolled, locked_out, lockout_remaining_seconds} or null on error.
  static Future<Map<String, dynamic>?> getStatus() async {
    try {
      final res =
          await http.get(Uri.parse('$_base/status')).timeout(const Duration(seconds: 5));
      return _parseBody(res);
    } catch (_) {
      return null;
    }
  }

  // ── Enrollment ─────────────────────────────────────────────────────

  /// Send a WAV file for voice enrollment.
  /// Returns the parsed JSON response or null on error.
  static Future<Map<String, dynamic>?> enroll(File audioFile) async {
    try {
      final bytes = await audioFile.readAsBytes();
      final req =
          http.MultipartRequest('POST', Uri.parse('$_base/enroll'));
      req.files.add(http.MultipartFile.fromBytes(
        'audio',
        bytes,
        filename: 'voice.wav',
      ));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res     = await http.Response.fromStream(streamed);
      return _parseBody(res);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Verification (Login) ───────────────────────────────────────────

  /// Send a WAV file for voice verification.
  /// Includes a Unix timestamp for anti-replay protection.
  /// Returns the parsed JSON response including 'token' on success.
  static Future<Map<String, dynamic>?> verify(File audioFile) async {
    try {
      final bytes = await audioFile.readAsBytes();
      final req   =
          http.MultipartRequest('POST', Uri.parse('$_base/verify'));

      // Anti-replay: current UNIX timestamp sent with every request.
      // The server rejects requests older than 30 seconds.
      req.fields['timestamp'] =
          (DateTime.now().millisecondsSinceEpoch / 1000).toString();

      req.files.add(http.MultipartFile.fromBytes(
        'audio',
        bytes,
        filename: 'voice.wav',
      ));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res     = await http.Response.fromStream(streamed);
      return _parseBody(res);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Reset enrollment ───────────────────────────────────────────────

  static Future<bool> resetEnrollment() async {
    try {
      final res = await http.post(Uri.parse('$_base/reset'))
          .timeout(const Duration(seconds: 5));
      return (json.decode(res.body)['success'] == true);
    } catch (_) {
      return false;
    }
  }

  // ── Vault CRUD ─────────────────────────────────────────────────────

  /// Fetch all vault entries.
  static Future<List<Map<String, dynamic>>> getEntries(String token) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/vault/entries'),
              headers: _authHeader(token))
          .timeout(const Duration(seconds: 10));
      final body = _parseBody(res);
      final list = body?['entries'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Search entries by keyword.
  static Future<List<Map<String, dynamic>>> searchEntries(
      String token, String query) async {
    try {
      final res = await http
          .post(Uri.parse('$_base/vault/search'),
              headers: {
                ..._authHeader(token),
                'Content-Type': 'application/json',
              },
              body: json.encode({'query': query}))
          .timeout(const Duration(seconds: 10));
      final body = _parseBody(res);
      final list = body?['entries'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Add a new vault entry.
  static Future<bool> addEntry(String token, Map<String, dynamic> data) async {
    try {
      final res = await http
          .post(Uri.parse('$_base/vault/add'),
              headers: {
                ..._authHeader(token),
                'Content-Type': 'application/json',
              },
              body: json.encode(data))
          .timeout(const Duration(seconds: 10));
      return (json.decode(res.body)['success'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Update an existing vault entry.
  static Future<bool> updateEntry(
      String token, int id, Map<String, dynamic> data) async {
    try {
      final res = await http
          .put(Uri.parse('$_base/vault/update/$id'),
              headers: {
                ..._authHeader(token),
                'Content-Type': 'application/json',
              },
              body: json.encode(data))
          .timeout(const Duration(seconds: 10));
      return (json.decode(res.body)['success'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Delete a vault entry by id.
  static Future<bool> deleteEntry(String token, int id) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/vault/delete/$id'),
              headers: _authHeader(token))
          .timeout(const Duration(seconds: 10));
      return (json.decode(res.body)['success'] == true);
    } catch (_) {
      return false;
    }
  }
}
