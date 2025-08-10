import 'package:hive/hive.dart';

class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final typeId =
      1; // keep this consistent with whatever you've already registered

  // Unit tags
  static const int _days = 0;
  static const int _hours = 1;
  static const int _minutes = 2;
  static const int _seconds = 3;
  static const int _milliseconds = 4;
  static const int _microseconds = 5;

  @override
  Duration read(BinaryReader reader) {
    final unit = reader.readByte();
    final value = reader.readInt(); // signed integer

    switch (unit) {
      case _days:
        return Duration(days: value);
      case _hours:
        return Duration(hours: value);
      case _minutes:
        return Duration(minutes: value);
      case _seconds:
        return Duration(seconds: value);
      case _milliseconds:
        return Duration(milliseconds: value);
      case _microseconds:
        return Duration(microseconds: value);
      default:
        // Fallback: if somehow invalid, treat as microseconds to avoid crash
        return Duration(microseconds: value);
    }
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    final micro = obj.inMicroseconds;

    if (micro % Duration.microsecondsPerDay == 0) {
      writer.writeByte(_days);
      writer.writeInt(micro ~/ Duration.microsecondsPerDay);
    } else if (micro % Duration.microsecondsPerHour == 0) {
      writer.writeByte(_hours);
      writer.writeInt(micro ~/ Duration.microsecondsPerHour);
    } else if (micro % Duration.microsecondsPerMinute == 0) {
      writer.writeByte(_minutes);
      writer.writeInt(micro ~/ Duration.microsecondsPerMinute);
    } else if (micro % Duration.microsecondsPerSecond == 0) {
      writer.writeByte(_seconds);
      writer.writeInt(micro ~/ Duration.microsecondsPerSecond);
    } else if (micro % Duration.microsecondsPerMillisecond == 0) {
      writer.writeByte(_milliseconds);
      writer.writeInt(micro ~/ Duration.microsecondsPerMillisecond);
    } else {
      writer.writeByte(_microseconds);
      writer.writeInt(micro);
    }
  }
}
