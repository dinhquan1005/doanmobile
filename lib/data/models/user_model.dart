import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_parser.dart';

enum UserRole {
  customer,
  staff,
  admin;

  static UserRole fromString(String? value) {
    return switch (value?.toLowerCase()) {
      'admin' => UserRole.admin,
      'staff' => UserRole.staff,
      _ => UserRole.customer,
    };
  }
}

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    this.role = UserRole.customer,
    this.defaultAddressId,
    this.fcmTokens = const <String>[],
    this.isBlocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final UserRole role;
  final String? defaultAddressId;
  final List<String> fcmTokens;
  final bool isBlocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAdmin => role == UserRole.admin;
  bool get isStaffOrAdmin =>
      role == UserRole.admin || role == UserRole.staff;

  factory UserModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, {
        UserRole? claimRoleOverride,
      }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final dbRole = UserRole.fromString(
      FirestoreParser.parseNullableString(data['role']),
    );
    return UserModel(
      id: doc.id,
      email: FirestoreParser.parseString(data['email']),
      fullName: FirestoreParser.parseString(
        data['fullName'],
        fallback: 'Khách hàng',
      ),
      phoneNumber: FirestoreParser.parseNullableString(data['phoneNumber']),
      avatarUrl: FirestoreParser.parseNullableString(data['avatarUrl']),
      role: claimRoleOverride ?? dbRole,
      defaultAddressId: FirestoreParser.parseNullableString(
        data['defaultAddressId'],
      ),
      fcmTokens: FirestoreParser.parseStringList(data['fcmTokens']),
      isBlocked: FirestoreParser.parseBool(data['isBlocked']),
      createdAt: FirestoreParser.parseDateTime(data['createdAt']),
      updatedAt: FirestoreParser.parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreCreateMap() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'role': role.name,
      'defaultAddressId': defaultAddressId,
      'fcmTokens': fcmTokens,
      'isBlocked': isBlocked,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
    UserRole? role,
    String? defaultAddressId,
    List<String>? fcmTokens,
    bool? isBlocked,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      defaultAddressId: defaultAddressId ?? this.defaultAddressId,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    phoneNumber,
    avatarUrl,
    role,
    defaultAddressId,
    fcmTokens,
    isBlocked,
    createdAt,
    updatedAt,
  ];
}