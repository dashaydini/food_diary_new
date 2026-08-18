// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaceAdapter extends TypeAdapter<Place> {
  @override
  final int typeId = 3;

  @override
  Place read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Place(
      name: fields[0] as String,
      location: fields[1] as String,
      visits: (fields[2] as List).cast<dynamic>(),
      imageBase64: fields[3] as String,
      favorite: fields[4] as bool,
      latitude: fields[5] as double,
      longitude: fields[6] as double,
      firebaseId: fields[7] as String,
      ownerName: fields[8] as String,
      createdAt: fields[9] as DateTime?,
      ownerId: fields[10] as String,
      category: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Place obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.location)
      ..writeByte(2)
      ..write(obj.visits)
      ..writeByte(3)
      ..write(obj.imageBase64)
      ..writeByte(4)
      ..write(obj.favorite)
      ..writeByte(5)
      ..write(obj.latitude)
      ..writeByte(6)
      ..write(obj.longitude)
      ..writeByte(7)
      ..write(obj.firebaseId)
      ..writeByte(8)
      ..write(obj.ownerName)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.ownerId)
      ..writeByte(11)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
