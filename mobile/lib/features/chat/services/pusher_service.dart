import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../models/chat_message_model.dart';

class PusherService {
  static final PusherService _instance = PusherService._internal();
  factory PusherService() => _instance;
  PusherService._internal();

  final PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
  bool _isInitialized = false;

  Future<void> init({
    required int currentUserId,
    required Function(ChatMessageModel) onMessageReceived,
  }) async {
    if (_isInitialized) return;

    try {
      final apiKey = dotenv.env['PUSHER_KEY'] ?? '';
      final cluster = dotenv.env['PUSHER_CLUSTER'] ?? '';

      await pusher.init(
        apiKey: apiKey,
        cluster: cluster,
        onEvent: (event) {
          if (event.eventName == 'new-message') {
            final data = jsonDecode(event.data.toString());
            final message = ChatMessageModel.fromJson(data);
            // We shouldn't duplicate messages we sent ourselves (handled by optimistic UI)
            if (message.senderId != currentUserId) {
              onMessageReceived(message);
            }
          }
        },
      );

      await pusher.connect();
      
      // Subscribe to personal channel to receive messages directed to this user
      await pusher.subscribe(channelName: 'private-chat-$currentUserId');
      // Subscribe to global management channel if this user is a manager
      // We will let the provider handle specific subscriptions based on role
      _isInitialized = true;
    } catch (e) {
      debugPrint("Pusher initialization error: $e");
    }
  }

  Future<void> subscribeToManagementChannel() async {
    try {
      await pusher.subscribe(channelName: 'presence-management');
    } catch (e) {
      debugPrint("Error subscribing to management channel: $e");
    }
  }

  Future<void> disconnect() async {
    if (_isInitialized) {
      await pusher.disconnect();
      _isInitialized = false;
    }
  }
}
