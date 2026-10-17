import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class DateTimeFormatter {
  DateTimeFormatter._();

  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'vi_VN');
  static final DateFormat _dateOnlyFormat = DateFormat('dd/MM/yyyy', 'vi_VN');
  static final DateFormat _timeOnlyFormat = DateFormat('HH:mm', 'vi_VN');

  /// Chuyển bất kỳ DateTime nào về giờ chuẩn Việt Nam (UTC+7)
  static DateTime toVietnamTime(DateTime dateTime) {
    return dateTime.toUtc().add(AppConstants.vietnamTimeZoneOffset);
  }

  /// Định dạng đầy đủ ngày và giờ theo múi giờ Việt Nam: "17/10/2026 14:30"
  static String formatDateTime(DateTime dateTime) {
    final vnTime = toVietnamTime(dateTime);
    return _dateTimeFormat.format(vnTime);
  }

  /// Định dạng chỉ ngày theo múi giờ Việt Nam: "17/10/2026"
  static String formatDate(DateTime dateTime) {
    final vnTime = toVietnamTime(dateTime);
    return _dateOnlyFormat.format(vnTime);
  }

  /// Định dạng chỉ giờ theo múi giờ Việt Nam: "14:30"
  static String formatTime(DateTime dateTime) {
    final vnTime = toVietnamTime(dateTime);
    return _timeOnlyFormat.format(vnTime);
  }
}