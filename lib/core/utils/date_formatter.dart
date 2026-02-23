import 'package:intl/intl.dart';

class DateFormatter
{
  static String format(DateTime date)
  {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatWithTime(DateTime date)
  {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
}