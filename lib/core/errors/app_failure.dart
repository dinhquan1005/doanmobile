import 'package:equatable/equatable.dart';

sealed class AppFailure extends Equatable {
  const AppFailure({
    required this.message,
    this.code,
  });

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.message = 'Không thể kết nối mạng. Vui lòng kiểm tra kết nối Internet và thử lại.',
    super.code = 'network-error',
  });
}

class AuthFailure extends AppFailure {
  const AuthFailure({
    required super.message,
    super.code,
  });
}

class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure({
    super.message = 'Bạn không có quyền thực hiện thao tác này.',
    super.code = 'permission-denied',
  });
}

class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.message,
    super.code = 'validation-error',
  });
}

class InsufficientStockFailure extends AppFailure {
  const InsufficientStockFailure({
    required this.productName,
    required this.availableStock,
  }) : super(
    message:
    'Sản phẩm "$productName" chỉ còn $availableStock sản phẩm trong kho.',
    code: 'insufficient-stock',
  );

  final String productName;
  final int availableStock;

  @override
  List<Object?> get props => [message, code, productName, availableStock];
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    super.message = 'Không tìm thấy dữ liệu yêu cầu.',
    super.code = 'not-found',
  });
}

class ServerFailure extends AppFailure {
  const ServerFailure({
    super.message = 'Đã xảy ra lỗi từ hệ thống máy chủ. Vui lòng thử lại sau.',
    super.code = 'server-error',
  });
}