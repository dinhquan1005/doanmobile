import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_parser.dart';

class ShippingAddressModel extends Equatable {
  const ShippingAddressModel({
    required this.id,
    required this.recipientName,
    required this.phoneNumber,
    required this.province,
    required this.district,
    required this.ward,
    required this.streetAddress,
    this.isDefault = false,
  });

  final String id;
  final String recipientName;
  final String phoneNumber;
  final String province;
  final String district;
  final String ward;
  final String streetAddress;
  final bool isDefault;

  String get fullAddressText =>
      '$streetAddress, $ward, $district, $province';

  factory ShippingAddressModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ShippingAddressModel.fromMap(data, fallbackId: doc.id);
  }

  factory ShippingAddressModel.fromMap(
      Map<String, dynamic> data, {
        String fallbackId = 'addr',
      }) {
    return ShippingAddressModel(
      id: FirestoreParser.parseString(data['id'], fallback: fallbackId),
      recipientName: FirestoreParser.parseString(data['recipientName']),
      phoneNumber: FirestoreParser.parseString(data['phoneNumber']),
      province: FirestoreParser.parseString(data['province']),
      district: FirestoreParser.parseString(data['district']),
      ward: FirestoreParser.parseString(data['ward']),
      streetAddress: FirestoreParser.parseString(data['streetAddress']),
      isDefault: FirestoreParser.parseBool(data['isDefault']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'recipientName': recipientName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'province': province.trim(),
      'district': district.trim(),
      'ward': ward.trim(),
      'streetAddress': streetAddress.trim(),
      'fullAddressText': fullAddressText,
      'isDefault': isDefault,
    };
  }

  ShippingAddressModel copyWith({
    String? id,
    String? recipientName,
    String? phoneNumber,
    String? province,
    String? district,
    String? ward,
    String? streetAddress,
    bool? isDefault,
  }) {
    return ShippingAddressModel(
      id: id ?? this.id,
      recipientName: recipientName ?? this.recipientName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      province: province ?? this.province,
      district: district ?? this.district,
      ward: ward ?? this.ward,
      streetAddress: streetAddress ?? this.streetAddress,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  List<Object?> get props => [
    id,
    recipientName,
    phoneNumber,
    province,
    district,
    ward,
    streetAddress,
    isDefault,
  ];
}