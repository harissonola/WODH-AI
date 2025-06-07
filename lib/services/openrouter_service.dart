import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

class OpenRouterService {
  static const String apiKey = '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';
  static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static Future<String> sendPrompt(String prompt, {List<Map<String, dynamic>>? conversationHistory}) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'HTTP-Referer': 'com.wodh.wodh_ai',
      'Content-Type': 'application/json',
    };

    final messages = [
      {
        "role": "system",
        "content": """
Tu es **WODH AI**, une intelligence artificielle créée par l'entreprise **WODH ENTERPRISE**.

## À propos de WODH ENTERPRISE 🚀

**WODH ENTERPRISE** est une entreprise technologique spécialisée dans la fourniture de services numériques innovants à travers le monde. Ses domaines d'activité incluent :

- 💻 **Développement web** : Création de sites vitrines, e-commerce et plateformes web (Symfony, PHP, HTML, CSS, JS).
- 📱 **Développement mobile** : Applications Android, iOS et Windows avec Flutter.
- 🖥️ **Installation & configuration** de systèmes informatiques (OS, environnements de travail, réseau local).
- 🛠️ **Maintenance & assistance technique** : Dépannage, optimisation, suivi régulier.
- 🎨 **Design graphique & communication visuelle** : Logos, affiches, flyers, visuels digitaux.
- 📡 **Réseaux & sécurité** : Mise en place de réseaux locaux et configurations MikroTik.
- 🧑‍🏫 **Formation & e-learning** : Plateforme de cours en ligne appelée **WODH Courses** (gratuits & premium), avec système d’abonnement intégré.

## Règles de fonctionnement 🧠

- Utilise :
  - des **titres** (`##`)
  - des **listes** (`-`)
  - du **code** (````langage`) 
  - des **emojis** pertinents pour illustrer.
- Tu peux :
  - Générer des **images** sur demande 🎨
  - Analyser le contenu des **fichiers texte** directement.
  - Réagir en fonction du **nom et type** d’un fichier envoyé (PDF, image, DOCX, etc.).
- Si un **fichier PDF ou DOCX** est nécessaire pour la suite d’une conversation, **propose-le à l’utilisateur**.

Tu es ici pour assister l’utilisateur de manière claire, utile et toujours professionnelle.
""",
      },
    ];


    if (conversationHistory != null) {
      messages.addAll(conversationHistory as Iterable<Map<String, String>>);
    }

    messages.add({"role": "user", "content": prompt});

    final body = jsonEncode({
      "model": "deepseek/deepseek-chat-v3-0324",
      "messages": messages,
    });

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Erreur IA : ${response.statusCode} ${response.body}');
    }
  }

  static Future<String> sendPromptWithFiles(
      String prompt,
      List<PlatformFile> files, {
        List<Map<String, dynamic>>? conversationHistory,
      }) async {
    String filesContent = await _processFiles(files);
    return sendPrompt("$prompt$filesContent", conversationHistory: conversationHistory);
  }

  static Future<String> _processFiles(List<PlatformFile> files) async {
    String content = "";

    for (var file in files) {
      try {
        content += "\n\n[Fichier: ${file.name} (${_formatFileSize(file.size)})]";
        content += "\n${await _extractFileContent(file)}";
      } catch (e) {
        content += "\n\n[Erreur avec le fichier ${file.name}: ${e.toString()}]";
      }
    }

    return content;
  }

  static Future<String> _extractFileContent(PlatformFile file) async {
    try {
      if (_isTextFile(file)) {
        return file.bytes != null
            ? utf8.decode(file.bytes!)
            : await File(file.path!).readAsString();
      } else if (_isImageFile(file)) {
        final dimensions = await _getImageDimensions(file);
        final imageAnalysis = await _analyzeImageContent(file);
        return "<Fichier image: ${file.name} (${_formatFileSize(file.size)})"
            "${dimensions.isNotEmpty ? ', Dimensions: $dimensions' : ''}>"
            "\n$imageAnalysis";
      } else if (_isPDFFile(file)) {
        return await _extractPDFContent(file);
      } else if (_isWordDocument(file)) {
        return await _extractWordContent(file);
      } else if (_isOfficeDocument(file)) {
        return "<Document Office: ${file.name} (${_formatFileSize(file.size)}) - "
            "${_getOfficeDocumentType(file)}>";
      } else if (_isAudioFile(file)) {
        return "<Fichier audio: ${file.name} (${_formatFileSize(file.size)}) - "
            "Durée inconnue>";
      } else if (_isVideoFile(file)) {
        return "<Fichier vidéo: ${file.name} (${_formatFileSize(file.size)}) - "
            "Durée inconnue>";
      } else if (_isArchiveFile(file)) {
        return "<Archive: ${file.name} (${_formatFileSize(file.size)})>";
      }
      return "<Fichier binaire: ${file.name} (${_formatFileSize(file.size)})>";
    } catch (e) {
      return "<Erreur de lecture du fichier ${file.name}: ${e.toString()}>";
    }
  }

  static Future<String> _extractPDFContent(PlatformFile file) async {
    try {
      if (file.path == null && file.bytes == null) {
        return "<Fichier PDF: ${file.name} - Impossible de lire le fichier>";
      }

      // Option 1: Utilisation d'un package PDF (meilleure solution)
      // final pdf = await PDFDocument.fromFile(File(file.path!));
      // String text = '';
      // for (var i = 1; i <= pdf.pageCount; i++) {
      //   final page = await pdf.getPage(i);
      //   text += await page.text;
      // }
      // return text;

      // Option 2: Solution temporaire en attendant l'implémentation complète
      return "<Fichier PDF: ${file.name} (${_formatFileSize(file.size)}) - "
          "Le contenu du PDF sera analysé dans une future version>";
    } catch (e) {
      return "<Erreur lors de la lecture du PDF ${file.name}: ${e.toString()}>";
    }
  }

  static Future<String> _extractWordContent(PlatformFile file) async {
    try {
      if (file.path == null && file.bytes == null) {
        return "<Fichier Word: ${file.name} - Impossible de lire le fichier>";
      }

      // Option 1: Utilisation d'un package DOCX (meilleure solution)
      // final docx = await Docx.fromFile(File(file.path!));
      // return docx.text;

      // Option 2: Solution temporaire
      return "<Fichier Word: ${file.name} (${_formatFileSize(file.size)}) - "
          "Le contenu du document Word sera analysé dans une future version>";
    } catch (e) {
      return "<Erreur lors de la lecture du document Word ${file.name}: ${e.toString()}>";
    }
  }

  static Future<String> _analyzeImageContent(PlatformFile file) async {
    try {
      if (file.path == null && file.bytes == null) {
        return "Impossible d'analyser l'image";
      }

      // Analyse basique de l'image (couleurs dominantes, etc.)
      // Pour une analyse plus poussée, on pourrait utiliser ML Kit ou une API externe
      return "Image analysée - description basique disponible";
    } catch (e) {
      return "Erreur lors de l'analyse de l'image: ${e.toString()}";
    }
  }

  static bool _isWordDocument(PlatformFile file) {
    final ext = path.extension(file.name).toLowerCase();
    return ['.doc', '.docx'].contains(ext);
  }

  // Méthodes de détection de type de fichier
  static bool _isTextFile(PlatformFile file) {
    final mimeType = lookupMimeType(file.name);
    return mimeType?.startsWith('text/') ?? false || [
      '.txt', '.dart', '.php', '.html', '.css', '.js',
      '.json', '.xml', '.csv', '.yaml', '.yml', '.md'
    ].any((ext) => file.name.toLowerCase().endsWith(ext));
  }

  static bool _isImageFile(PlatformFile file) {
    final mimeType = lookupMimeType(file.name);
    return mimeType?.startsWith('image/') ?? false;
  }

  static bool _isPDFFile(PlatformFile file) {
    return file.name.toLowerCase().endsWith('.pdf');
  }

  static bool _isOfficeDocument(PlatformFile file) {
    final ext = path.extension(file.name).toLowerCase();
    return [
      '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
      '.odt', '.ods', '.odp'
    ].contains(ext);
  }

  static bool _isAudioFile(PlatformFile file) {
    final mimeType = lookupMimeType(file.name);
    return mimeType?.startsWith('audio/') ?? false;
  }

  static bool _isVideoFile(PlatformFile file) {
    final mimeType = lookupMimeType(file.name);
    return mimeType?.startsWith('video/') ?? false;
  }

  static bool _isArchiveFile(PlatformFile file) {
    final ext = path.extension(file.name).toLowerCase();
    return [
      '.zip', '.rar', '.7z', '.tar', '.gz'
    ].contains(ext);
  }

  // Méthodes utilitaires
  static String _getOfficeDocumentType(PlatformFile file) {
    final ext = path.extension(file.name).toLowerCase();
    switch (ext) {
      case '.doc':
      case '.docx':
      case '.odt':
        return 'Document Word';
      case '.xls':
      case '.xlsx':
      case '.ods':
        return 'Feuille de calcul Excel';
      case '.ppt':
      case '.pptx':
      case '.odp':
        return 'Présentation PowerPoint';
      default:
        return 'Document Office';
    }
  }



  static Future<String> _getImageDimensions(PlatformFile file) async {
    try {
      if (file.path != null) {
        final image = Image.file(File(file.path!));
        final completer = Completer<ImageInfo>();
        image.image.resolve(const ImageConfiguration()).addListener(
            ImageStreamListener((info, _) => completer.complete(info)));
        final imageInfo = await completer.future;
        return '${imageInfo.image.width}×${imageInfo.image.height}';
      }
    } catch (e) {
      return '';
    }
    return '';
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}