import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../services/openrouter_service.dart';


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<PlatformFile> _selectedFiles = [];
  bool _isSending = false;
  bool _showScrollToBottomButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    setState(() {
      _showScrollToBottomButton = currentScroll < maxScroll - 50;
    });
  }

  Future<void> _scrollToBottom() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final validFiles = result.files.where((f) {
          if (f.size <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Le fichier ${f.name} est vide et sera ignoré'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
            return false;
          }

          if (f.size > 50 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Le fichier ${f.name} dépasse 50MB et sera ignoré'),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }

          return true;
        }).toList();

        if (validFiles.isNotEmpty) {
          setState(() {
            _selectedFiles = validFiles;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${validFiles.length} fichier(s) sélectionné(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          });
        }
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de sélection: ${e.message ?? 'Inconnue'}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur inattendue: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateTitleFromContent(String content) {
    if (content.isEmpty) return "Nouvelle conversation";
    final words = content.split(' ').where((word) => word.length > 3).take(4).toList();
    if (words.isEmpty) return content.substring(0, content.length < 20 ? content.length : 20);
    return words.join(' ');
  }

  Future<void> sendMessage() async {
    if (_controller.text.trim().isEmpty && _selectedFiles.isEmpty) return;

    setState(() => _isSending = true);
    final content = _controller.text;
    _controller.clear();

    final provider = Provider.of<ConversationProvider>(context, listen: false);

    if (provider.currentConversation?.messages.isEmpty ?? true) {
      final generatedTitle = _generateTitleFromContent(content);
      provider.updateConversationTitle(provider.currentConversation!.id, generatedTitle);
    }

    provider.addMessageToCurrent(
        content + (_selectedFiles.isNotEmpty
            ? " (${_selectedFiles.length} fichier(s) joint(s)${_containsUnsupportedFiles(_selectedFiles) ? ' [certains fichiers nécessitent une analyse avancée]' : ''})"
            : ""),
        true
    );

    // Faites défiler vers le bas immédiatement après avoir ajouté le message utilisateur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      final conversationHistory = provider.currentConversation?.messages
          .where((msg) => msg.content.isNotEmpty)
          .map((msg) => {
        "role": msg.isUser ? "user" : "assistant",
        "content": msg.content,
      }).toList();

      final response = _selectedFiles.isNotEmpty
          ? await OpenRouterService.sendPromptWithFiles(
        content.isNotEmpty ? content : "Analysez ces fichiers",
        _selectedFiles,
        conversationHistory: conversationHistory,
      )
          : await OpenRouterService.sendPrompt(
        content,
        conversationHistory: conversationHistory,
      );

      provider.addMessageToCurrent(response, false);

      // Faites défiler vers le bas après avoir ajouté la réponse de l'assistant
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      provider.addMessageToCurrent('Erreur: $e', false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } finally {
      setState(() {
        _selectedFiles = [];
        _isSending = false;
      });
    }
  }

  bool _containsNonTextFiles(List<PlatformFile> files) {
    return files.any((file) => !_isTextFile(file));
  }

  bool _isTextFile(PlatformFile file) {
    final mimeType = lookupMimeType(file.name);
    return mimeType?.startsWith('text/') ?? false || [
      '.txt', '.dart', '.php', '.html', '.css', '.js',
      '.json', '.xml', '.csv', '.yaml', '.yml', '.md'
    ].any((ext) => file.name.toLowerCase().endsWith(ext));
  }

  IconData _getFileIcon(PlatformFile file) {
    final fileName = file.name.toLowerCase();
    final ext = path.extension(fileName);

    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.txt': case '.dart': case '.php': case '.html': case '.css':
      case '.js': case '.json': case '.xml': case '.yaml': case '.yml':
      return Icons.code;
      case '.jpg': case '.jpeg': case '.png': case '.gif': case '.bmp':
      return Icons.image;
      case '.mp3': case '.wav': case '.ogg': case '.m4a':
      return Icons.audiotrack;
      case '.mp4': case '.mov': case '.avi': case '.mkv':
      return Icons.videocam;
      case '.zip': case '.rar': case '.7z': case '.tar': case '.gz':
      return Icons.archive;
      case '.doc': case '.docx': case '.odt':
      return Icons.article;
      case '.xls': case '.xlsx': case '.ods':
      return Icons.table_chart;
      case '.ppt': case '.pptx': case '.odp':
      return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  bool _containsUnsupportedFiles(List<PlatformFile> files) {
    return files.any((file) =>
    !_isTextFile(file) &&
        !_isImageFile(file) &&
        !_isPDFFile(file) &&
        !_isWordDocument(file));
  }

  bool _isImageFile(PlatformFile file) {
    final mimeType = lookupMimeType(file.name);
    return mimeType?.startsWith('image/') ?? false || [
      '.jpg', '.jpeg', '.png', '.gif', '.bmp'
    ].any((ext) => file.name.toLowerCase().endsWith(ext));
  }

  bool _isPDFFile(PlatformFile file) {
    final mimeType = lookupMimeType(file.name);
    return mimeType == 'application/pdf' || file.name.toLowerCase().endsWith('.pdf');
  }

  bool _isWordDocument(PlatformFile file) {
    final ext = path.extension(file.name).toLowerCase();
    return ['.doc', '.docx'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final conversation = Provider.of<ConversationProvider>(context).currentConversation;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          conversation?.title ?? 'Nouvelle conversation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 4.0,
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade700,
                Colors.purpleAccent.shade400,
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 10,
        shadowColor: Colors.deepPurple.withOpacity(0.5),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.deepPurple.shade50,
                  Colors.deepPurple.shade100,
                ],
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Consumer<ConversationProvider>(
                    builder: (context, provider, _) {
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: conversation?.messages.length ?? 0,
                        itemBuilder: (context, index) {
                          final message = conversation!.messages[index];
                          return MessageBubble(
                            message: message.content,
                            isUser: message.isUser,
                            time: message.formattedTime,
                          );
                        },
                      );
                    },
                  ),
                ),
                if (_selectedFiles.isNotEmpty)
                  Container(
                    height: 100,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _selectedFiles[index];
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepPurple.shade100,
                                    Colors.purple.shade100,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepPurple.withOpacity(0.2),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getFileIcon(file),
                                      size: 28,
                                      color: Colors.deepPurple,
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        file.name.split('/').last,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${(file.size / 1024).toStringAsFixed(1)} KB',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.deepPurple.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFiles.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.deepPurple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade400,
                              Colors.purpleAccent.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.white),
                          onPressed: _isSending ? null : _pickFiles,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.1),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _controller,
                            enabled: !_isSending,
                            decoration: InputDecoration(
                              hintText: 'Écrivez votre message...',
                              hintStyle: TextStyle(
                                color: Colors.deepPurple.withOpacity(0.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            style: TextStyle(
                              color: Colors.deepPurple.shade800,
                            ),
                            onSubmitted: (_) => sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isSending
                                ? [Colors.grey, Colors.grey.shade600]
                                : [
                              Colors.deepPurple.shade400,
                              Colors.purpleAccent.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: _isSending
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.send, color: Colors.white),
                          onPressed: _isSending ? null : sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 100,
            child: AnimatedOpacity(
              opacity: _showScrollToBottomButton ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.deepPurple,
                child: const Icon(Icons.arrow_downward, color: Colors.white),
                onPressed: _scrollToBottom,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatefulWidget {
  final String message;
  final bool isUser;
  final String time;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.time,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

// Supprimez toute la classe TypewriterText (lignes 17-55)

// Modifiez la classe _MessageBubbleState comme suit :
class _MessageBubbleState extends State<MessageBubble> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        mainAxisAlignment: widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!widget.isUser)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                child: Icon(
                  Icons.smart_toy,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isUser
                      ? [
                    Colors.deepPurple.shade600,
                    Colors.purpleAccent.shade400,
                  ]
                      : [
                    Colors.grey.shade100,
                    Colors.grey.shade50,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: widget.isUser
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: widget.isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: widget.message,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: widget.isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.4,
                      ),
                      code: TextStyle(
                        color: widget.isUser ? Colors.white : Colors.deepPurple,
                        backgroundColor: widget.isUser
                            ? Colors.deepPurple.withOpacity(0.3)
                            : Colors.deepPurple.withOpacity(0.1),
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: widget.isUser
                            ? Colors.deepPurple.withOpacity(0.3)
                            : Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      h1: TextStyle(
                        color: widget.isUser ? Colors.white : Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      h2: TextStyle(
                        color: widget.isUser ? Colors.white : Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      h3: TextStyle(
                        color: widget.isUser ? Colors.white : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      h4: TextStyle(
                        color: widget.isUser ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      h5: TextStyle(
                        color: widget.isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      h6: TextStyle(
                        color: widget.isUser ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      em: TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                      strong: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                      blockquote: TextStyle(
                        color: widget.isUser ? Colors.white : Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: TextStyle(
                        color: widget.isUser ? Colors.white : Colors.black87,
                      ),
                      tableBorder: TableBorder.all(
                        color: widget.isUser ? Colors.white54 : Colors.black54,
                        width: 1,
                      ),
                      tableCellsDecoration: BoxDecoration(
                        color: widget.isUser
                            ? Colors.deepPurple.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.time,
                    style: TextStyle(
                      color: widget.isUser
                          ? Colors.white.withOpacity(0.8)
                          : Colors.black.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isUser)
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                backgroundColor: Colors.deepPurple.withOpacity(0.2),
                child: Icon(
                  Icons.person,
                  color: Colors.deepPurple,
                ),
              ),
            ),
        ],
      ),
    );
  }
}