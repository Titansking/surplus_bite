import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';

class Formatters {
  static String currency(double amount) {
    return NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(amount);
  }

  static String date(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('MMM d, yyyy • h:mm a').format(date);
  }

  static String shortDate(DateTime date) {
    return DateFormat('MMM d').format(date);
  }

  static String time(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String pickupWindow(DateTime start, DateTime end) {
    return '${time(start)} - ${time(end)}';
  }

  static String relativeTime(DateTime date) {
    return timeago.format(date, allowFromNow: true);
  }

  static String discount(double percent) {
    return '${percent.toStringAsFixed(0)}% OFF';
  }

  static String rating(double rating) {
    return rating.toStringAsFixed(1);
  }

  static String gramsToKg(double grams) {
    if (grams >= 1000) {
      return '${(grams / 1000).toStringAsFixed(1)} kg';
    }
    return '${grams.toStringAsFixed(0)} g';
  }

  static String co2Saved(double kg) {
    return '${kg.toStringAsFixed(1)} kg CO\u2082 saved';
  }

  static Timestamp toTimestamp(DateTime date) {
    return Timestamp.fromDate(date);
  }
}
