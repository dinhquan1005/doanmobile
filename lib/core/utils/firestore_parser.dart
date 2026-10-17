import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreParser {
  FirestoreParser._();

  static String parseString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      return value.trim();
    }
    if (value != null) {
      return value.toString().trim();
    }
    return fallback;
  }

  static String? parseNullableString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static int parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static double parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static bool parseBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return fallback;
  }

  static List<String> parseStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static DateTime parseDateTime(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}