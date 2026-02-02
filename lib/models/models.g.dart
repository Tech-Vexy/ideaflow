// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IdeaAdapter extends TypeAdapter<Idea> {
  @override
  final int typeId = 0;

  @override
  Idea read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Idea(
      id: fields[0] as String,
      title: fields[1] as String,
      createdAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Idea obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdeaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BrainstormSessionAdapter extends TypeAdapter<BrainstormSession> {
  @override
  final int typeId = 1;

  @override
  BrainstormSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BrainstormSession(
      id: fields[0] as String,
      ideaId: fields[1] as String,
      rawTranscript: fields[2] as String,
      aiInsight: fields[3] as String?,
      sessionDate: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BrainstormSession obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ideaId)
      ..writeByte(2)
      ..write(obj.rawTranscript)
      ..writeByte(3)
      ..write(obj.aiInsight)
      ..writeByte(4)
      ..write(obj.sessionDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrainstormSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
