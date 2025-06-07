// models/generated_file.dart
import 'dart:typed_data';
import 'package:uuid/uuid.dart';

class GeneratedFile {
  final String id;
  final String name;
  final String type;
  final Uint8List data;
  final String? mimeType;

  GeneratedFile({
    required this.name,
    required this.type,
    required this.data,
    this.mimeType,
    String? id,
  }) : id = id ?? const Uuid().v4();
}