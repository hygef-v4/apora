import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/chat_message_model.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int? partnerId; // null means chatting with general management
  final String title;

  const ChatScreen({
    super.key,
    this.partnerId,
    required this.title,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatMessagesProvider.notifier).loadChat(widget.partnerId);
      ref.read(chatMessagesProvider.notifier).markAsRead();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend({File? image}) async {
    final text = _textController.text.trim();
    if (text.isEmpty && image == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      _textController.clear();
      await ref.read(chatMessagesProvider.notifier).sendMessage(
            content: text,
            image: image,
          );
      
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      await _handleSend(image: File(pickedFile.path));
    }
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: message.isImage ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe && message.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            if (message.isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: message.content.startsWith('http')
                    ? Image.network(
                        message.content,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          );
                        },
                      )
                    : Image.file(
                        File(message.content),
                        fit: BoxFit.cover,
                      ),
              )
            else
              Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider);
    final currentUser = ref.watch(authNotifierProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('Chưa có tin nhắn nào.'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Show latest messages at the bottom
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser?.id;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi: $err')),
            ),
          ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image, color: AppColors.primary),
                    onPressed: _isSending ? null : _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLength: 1000,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _isSending ? null : () => _handleSend(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
