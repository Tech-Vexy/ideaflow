import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class Idea extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime createdAt;

  Idea({required this.id, required this.title, required this.createdAt});

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Idea.fromJson(Map<String, dynamic> json) => Idea(
    id: json['id'],
    title: json['title'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

@HiveType(typeId: 1)
class BrainstormSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String ideaId;

  @HiveField(2)
  final String rawTranscript;

  @HiveField(3)
  final String? aiInsight;

  @HiveField(4)
  final DateTime sessionDate;

  BrainstormSession({
    required this.id,
    required this.ideaId,
    required this.rawTranscript,
    this.aiInsight,
    required this.sessionDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'ideaId': ideaId,
    'rawTranscript': rawTranscript,
    'aiInsight': aiInsight,
    'sessionDate': sessionDate.toIso8601String(),
  };

  factory BrainstormSession.fromJson(Map<String, dynamic> json) =>
      BrainstormSession(
        id: json['id'],
        ideaId: json['ideaId'],
        rawTranscript: json['rawTranscript'],
        aiInsight: json['aiInsight'],
        sessionDate: DateTime.parse(json['sessionDate']),
      );
}

@HiveType(typeId: 2)
class ArrayChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String ideaId;

  @HiveField(2)
  final String text;

  @HiveField(3)
  final bool isUser;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5, defaultValue: false)
  final bool isThinking;

  ArrayChatMessage({
    required this.id,
    required this.ideaId,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isThinking = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'ideaId': ideaId,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'isThinking': isThinking,
  };

  factory ArrayChatMessage.fromJson(Map<String, dynamic> json) =>
      ArrayChatMessage(
        id: json['id'],
        ideaId: json['ideaId'],
        text: json['text'],
        isUser: json['isUser'],
        timestamp: DateTime.parse(json['timestamp']),
        isThinking: json['isThinking'] ?? false,
      );
}
