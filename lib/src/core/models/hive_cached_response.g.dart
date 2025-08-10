// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_cached_response.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveCachedResponseAdapter extends TypeAdapter<HiveCachedResponse> {
  @override
  final int typeId = 0;

  @override
  HiveCachedResponse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveCachedResponse(
      key: fields[0] as String,
      statusCode: fields[1] as int,
      data: fields[2] as String,
      headersJson: fields[3] as String,
      timestamp: fields[4] as DateTime,
      validity: fields[5] as Duration?,
      requestUrl: fields[6] as String,
      queryParameters: fields[7] as Map<String, dynamic>,
    );
  }

  @override
  void write(BinaryWriter writer, HiveCachedResponse obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.key)
      ..writeByte(1)
      ..write(obj.statusCode)
      ..writeByte(2)
      ..write(obj.data)
      ..writeByte(3)
      ..write(obj.headersJson)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.validity)
      ..writeByte(6)
      ..write(obj.requestUrl)
      ..writeByte(7)
      ..write(obj.queryParameters);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveCachedResponseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
