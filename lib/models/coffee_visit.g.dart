// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coffee_visit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CoffeeVisitAdapter extends TypeAdapter<CoffeeVisit> {
  @override
  final int typeId = 2;

  @override
  CoffeeVisit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoffeeVisit(
      dish: fields[0] as String,
      notes: fields[1] as String,
      atmosphere: fields[2] as double,
      cleanliness: fields[3] as double,
      service: fields[4] as double,
      foodQuality: fields[5] as double,
      variety: fields[6] as double,
      value: fields[7] as double,
      imageBase64: fields[8] as String,
      tags: (fields[9] as List).cast<String>(),
      date: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CoffeeVisit obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.dish)
      ..writeByte(1)
      ..write(obj.notes)
      ..writeByte(2)
      ..write(obj.atmosphere)
      ..writeByte(3)
      ..write(obj.cleanliness)
      ..writeByte(4)
      ..write(obj.service)
      ..writeByte(5)
      ..write(obj.foodQuality)
      ..writeByte(6)
      ..write(obj.variety)
      ..writeByte(7)
      ..write(obj.value)
      ..writeByte(8)
      ..write(obj.imageBase64)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoffeeVisitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
