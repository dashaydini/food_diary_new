// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coffee_cart.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CoffeeCartAdapter extends TypeAdapter<CoffeeCart> {
  @override
  final int typeId = 0;

  @override
  CoffeeCart read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoffeeCart(
      name: fields[0] as String,
      location: fields[1] as String,
      visits: (fields[2] as List).cast<CoffeeVisit>(),
      imageBase64: fields[3] as String,
      favorite: fields[4] as bool,
      latitude: fields[5] as double,
      longitude: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CoffeeCart obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.longitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoffeeCartAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
