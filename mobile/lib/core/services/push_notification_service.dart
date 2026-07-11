import 'dart:developer';

class PushNotificationService {
  Future<void> init() async {
    log('Firebase temporarily disabled');
  }

  Future<String?> getToken() async {
    return null;
  }
}

// Global instance
final pushNotificationService = PushNotificationService();
