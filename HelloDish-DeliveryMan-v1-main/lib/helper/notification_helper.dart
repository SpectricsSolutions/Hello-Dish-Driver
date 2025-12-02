import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/chat/controllers/chat_controller.dart';
import 'package:sixam_mart_delivery/features/dashboard/screens/dashboard_screen.dart';
import 'package:sixam_mart_delivery/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart_delivery/helper/custom_print_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:sixam_mart_delivery/helper/ringing_service.dart';

class NotificationHelper {

  static Future<void> initialize(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize = const AndroidInitializationSettings('notification_icon');
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationsSettings = InitializationSettings(android: androidInitialize, iOS: iOSInitialize);
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation < AndroidFlutterLocalNotificationsPlugin>()!.requestNotificationsPermission();
    flutterLocalNotificationsPlugin.initialize(initializationsSettings, onDidReceiveNotificationResponse: (load) async{
      try{
        if(load.payload!.isNotEmpty){
          NotificationBodyModel payload = NotificationBodyModel.fromJson(jsonDecode(load.payload!));

          final Map<NotificationType, Function> notificationActions = {
            NotificationType.order: () => Get.toNamed(RouteHelper.getOrderDetailsRoute(payload.orderId, fromNotification: true)),
            NotificationType.order_request: () => Get.toNamed(RouteHelper.getMainRoute('order-request')),
            NotificationType.block: () => Get.offAllNamed(RouteHelper.getSignInRoute()),
            NotificationType.unblock: () => Get.offAllNamed(RouteHelper.getSignInRoute()),
            NotificationType.otp: () => null,
            NotificationType.unassign: () => Get.to(const DashboardScreen(pageIndex: 1)),
            NotificationType.message: () => Get.toNamed(RouteHelper.getChatRoute(notificationBody: payload, conversationId: payload.conversationId, fromNotification: true)),
            NotificationType.withdraw: () => Get.toNamed(RouteHelper.getMyAccountRoute()),
            NotificationType.general: () => Get.toNamed(RouteHelper.getNotificationRoute(fromNotification: true)),
          };

          notificationActions[payload.notificationType]?.call();
        }
      }catch(_){}
      return;
    });

    // Ensure Android notification channel exists with sound enabled (use default system sound)
    try{
      final androidImpl = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if(androidImpl != null){
        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          '6ammart',
          AppConstants.appName,
          description: 'Important notifications for ${AppConstants.appName}',
          importance: Importance.max,
          playSound: true,
        );
        await androidImpl.createNotificationChannel(channel);
      }
    }catch(e){ customPrint('Error creating notification channel: $e'); }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print("onMessage message type:${message.data['type']}");
        print("onMessage message:${message.data}");
      }

      // Early stop: if this push indicates the request is no longer actionable (assigned/unassigned/status closed), stop ringing.
      if(_shouldStopRinging(message.data)){
        try{ await stopService(); }catch(e){ customPrint('Error stopping service on message: $e'); }
      }

      if(message.data['type'] == 'message' && Get.currentRoute.startsWith(RouteHelper.chatScreen)){
        if(Get.find<AuthController>().isLoggedIn()) {
          Get.find<ChatController>().getConversationList(1);
          if(Get.find<ChatController>().messageModel!.conversation!.id.toString() == message.data['conversation_id'].toString()) {
            Get.find<ChatController>().getMessages(
              1, NotificationBodyModel(
              notificationType: NotificationType.message,
              customerId: message.data['sender_type'] == AppConstants.user ? 0 : null,
              vendorId: message.data['sender_type'] == AppConstants.vendor ? 0 : null,
            ),
              null, int.parse(message.data['conversation_id'].toString()),
            );
          }else {
            NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
          }
        }
      }else if(message.data['type'] == 'message' && Get.currentRoute.startsWith(RouteHelper.conversationListScreen)) {
        if(Get.find<AuthController>().isLoggedIn()) {
          Get.find<ChatController>().getConversationList(1);
        }
        NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
      }else if(message.data['type'] == 'otp'){
        NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
      }else {
        String? type = message.data['type'];

        if (type != 'assign' && type != 'new_order' && type != 'order_request') {
          NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
          Get.find<OrderController>().getCurrentOrders();
          Get.find<OrderController>().getLatestOrders();
          Get.find<NotificationController>().getNotificationList();
        }

        // Start ringing for actionable new order events when app is in foreground
        if(type == 'new_order' || type == 'order_request'){
          try{
            FlutterForegroundTask.initCommunicationPort();
            await _initService();
            // mark ringing started so UI dialogs can stop when needed
            try{ Get.find<RingingService>().startRinging(); }catch(e){}
            await _startService(message.data['order_id']?.toString(), NotificationType.order_request);
          }catch(e){
            customPrint('Error starting service on foreground message: $e');
          }
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("onOpenApp message type:${message.data['type']}");
      }
      try{
        if(message.data.isNotEmpty){
          NotificationBodyModel? notificationBody = convertNotification(message.data);

          // Stop any foreground ringing/service when user taps/open notification that refers to order events
          try{
            stopService();
          }catch(e){
            customPrint('Error stopping service on open app: $e');
          }

          final Map<NotificationType, Function> notificationActions = {
            NotificationType.order: () => Get.toNamed(RouteHelper.getOrderDetailsRoute(int.parse(message.data['order_id']), fromNotification: true)),
            NotificationType.order_request: () => Get.toNamed(RouteHelper.getMainRoute('order-request')),
            NotificationType.block: () => Get.offAllNamed(RouteHelper.getSignInRoute()),
            NotificationType.unblock: () => Get.offAllNamed(RouteHelper.getSignInRoute()),
            NotificationType.otp: () => null,
            NotificationType.unassign: () => Get.to(const DashboardScreen(pageIndex: 1)),
            NotificationType.message: () {
              if(notificationBody != null) {
                return Get.toNamed(RouteHelper.getChatRoute(notificationBody: notificationBody, conversationId: notificationBody.conversationId, fromNotification: true));
              }
              return null;
            },
            NotificationType.withdraw: () => Get.toNamed(RouteHelper.getMyAccountRoute()),
            NotificationType.general: () => Get.toNamed(RouteHelper.getNotificationRoute(fromNotification: true)),
          };

          if(notificationBody != null) {
            notificationActions[notificationBody.notificationType]?.call();
          }
        }
      }catch (_) {}
    });
  }

  static Future<void> showNotification(RemoteMessage message, FlutterLocalNotificationsPlugin fln) async {
    if(!GetPlatform.isIOS) {
      String? title;
      String? body;
      String? image;
      NotificationBodyModel? notificationBody = convertNotification(message.data);

      title = message.data['title'];
      body = message.data['body'];
      image = (message.data['image'] != null && message.data['image'].isNotEmpty) ? message.data['image'].startsWith('http') ? message.data['image']
        : '${AppConstants.baseUrl}/storage/app/public/notification/${message.data['image']}' : null;

      if(image != null && image.isNotEmpty) {
        try{
          await showBigPictureNotificationHiddenLargeIcon(title, body, notificationBody, image, fln);
        }catch(e) {
          await showBigTextNotification(title, body!, notificationBody, fln);
        }
      }else {
        await showBigTextNotification(title, body!, notificationBody, fln);
      }
    }
  }

  static Future<void> showTextNotification(String title, String body, NotificationBodyModel notificationBody, FlutterLocalNotificationsPlugin fln) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      '6ammart', AppConstants.appName, playSound: true,
      importance: Importance.max, priority: Priority.max,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, title, body, platformChannelSpecifics, payload: jsonEncode(notificationBody.toJson()));
  }

  static Future<void> showBigTextNotification(String? title, String body, NotificationBodyModel? notificationBody, FlutterLocalNotificationsPlugin fln) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body, htmlFormatBigText: true,
      contentTitle: title, htmlFormatContentTitle: true,
    );
    AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      '6ammart', AppConstants.appName, importance: Importance.max,
      styleInformation: bigTextStyleInformation, priority: Priority.max, playSound: true,
    );
    NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, title, body, platformChannelSpecifics, payload: notificationBody != null ? jsonEncode(notificationBody.toJson()) : null);
  }

  static Future<void> showBigPictureNotificationHiddenLargeIcon(String? title, String? body, NotificationBodyModel? notificationBody, String image, FlutterLocalNotificationsPlugin fln) async {
    final String largeIconPath = await _downloadAndSaveFile(image, 'largeIcon');
    final String bigPicturePath = await _downloadAndSaveFile(image, 'bigPicture');
    final BigPictureStyleInformation bigPictureStyleInformation = BigPictureStyleInformation(
      FilePathAndroidBitmap(bigPicturePath), hideExpandedLargeIcon: true,
      contentTitle: title, htmlFormatContentTitle: true,
      summaryText: body, htmlFormatSummaryText: true,
    );
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      '6ammart', AppConstants.appName,
      largeIcon: FilePathAndroidBitmap(largeIconPath), priority: Priority.max, playSound: true,
      styleInformation: bigPictureStyleInformation, importance: Importance.max,
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, title, body, platformChannelSpecifics, payload: notificationBody != null ? jsonEncode(notificationBody.toJson()) : null);
  }

  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  static NotificationBodyModel? convertNotification(Map<String, dynamic> data){
    final type = data['type'];
    final orderId = data['order_id'];

    switch (type) {
      case 'cash_collect':
        return NotificationBodyModel(notificationType: NotificationType.general);
      case 'unassign':
        return NotificationBodyModel(notificationType: NotificationType.unassign);
      case 'order_status':
        return NotificationBodyModel(orderId: int.parse(orderId), notificationType: NotificationType.order);
      case 'order_request':
        return NotificationBodyModel(orderId: int.parse(orderId), notificationType: NotificationType.order_request);
      case 'new_order':
        return NotificationBodyModel(orderId: int.parse(orderId), notificationType: NotificationType.order_request);
      case 'block':
        return NotificationBodyModel(notificationType: NotificationType.block);
      case 'unblock':
        return NotificationBodyModel(notificationType: NotificationType.unblock);
      case 'otp':
        return NotificationBodyModel(notificationType: NotificationType.otp);
      case 'message':
        return _handleMessageNotification(data);
      case 'withdraw':
        return NotificationBodyModel(notificationType: NotificationType.withdraw);
      default:
        return NotificationBodyModel(notificationType: NotificationType.general);
    }
  }

  static NotificationBodyModel _handleMessageNotification(Map<String, dynamic> data) {
    final conversationId = data['conversation_id'];
    final senderType = data['sender_type'];

    return NotificationBodyModel(
      conversationId: (conversationId != null && conversationId.isNotEmpty) ? int.parse(conversationId) : null,
      notificationType: NotificationType.message,
      type: senderType == AppConstants.user ? AppConstants.user : AppConstants.vendor,
    );
  }

  // Decide if a push should stop the ringing/foreground service across devices
  static bool _shouldStopRinging(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null) return false;
    const stopTypes = {
      'assign',
      'unassign',
      'order_status',
      'order_request_close',
      'order_cancel',
      'order_canceled',
      'order_cancelled',
      'accepted',
      'order_accepted',
    };

    // quick check by type
    if (stopTypes.contains(type)) return true;

    // additional robust checks: if any field contains acceptance/assignment keywords, stop ringing
    final joinedValues = data.values.map((v) => v == null ? '' : v.toString().toLowerCase()).join(' ');
    if (joinedValues.contains('accepted') || joinedValues.contains('assigned') || joinedValues.contains('assign') || joinedValues.contains('order_accepted')) {
      return true;
    }

    // check status field explicitly
    final status = data.containsKey('status') && data['status'] != null ? data['status'].toString().toLowerCase() : null;
    if (status == 'accepted' || status == 'assigned' || status == 'completed' || status == 'cancelled') return true;

    return false;
  }

}



final AudioPlayer _audioPlayer = AudioPlayer();

/// Background FCM message handler
@pragma('vm:entry-point')
Future<void> myBackgroundMessageHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  customPrint("onBackground: ${message.data}");

  // If this background message indicates the request is closed/assigned, stop the service immediately
  if (NotificationHelper._shouldStopRinging(message.data)) {
    try { await stopService(); } catch (e) { customPrint('Error stopping service in background: $e'); }
    return;
  }

  final notificationBody = NotificationHelper.convertNotification(message.data);

  // Only start service for actionable new order requests
  if (notificationBody != null && (notificationBody.notificationType == NotificationType.order_request)) {
    FlutterForegroundTask.initCommunicationPort();
    await _initService();
    await _startService(notificationBody.orderId?.toString(), notificationBody.notificationType!);
  }
}

/// Initialize Foreground Service
@pragma('vm:entry-point')
Future<void> _initService() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: '6ammart',
      channelName: 'Foreground Service Notification',
      channelDescription: 'This notification appears when the foreground service is running.',
      onlyAlertOnce: false,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

/// Start Foreground Service
@pragma('vm:entry-point')
Future<ServiceRequestResult> _startService(String? orderId, NotificationType notificationType) async {
  // mark ringing started so UI can react (safe in try/catch because background isolate may not have DI)
  try{ Get.find<RingingService>().startRinging(); }catch(e){ customPrint('RingingService not available in this isolate: $e'); }
  if (await FlutterForegroundTask.isRunningService) {
    customPrint('Restarting foreground service for order: $orderId');
    return FlutterForegroundTask.restartService();
  } else {
    customPrint('Starting foreground service for order: $orderId');
    return FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: notificationType == NotificationType.order_request ? 'Order Notification' : 'You have been assigned a new order ($orderId)',
      notificationText: notificationType == NotificationType.order_request ? 'New order request arrived, you can confirm this.' : 'Open app and check order details.',
      callback: startCallback,
    );
  }
}

/// Stop Foreground Service
@pragma('vm:entry-point')
Future<ServiceRequestResult> stopService() async {
  customPrint('Stopping foreground service and audio');
  try {
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
  } catch (e) {
    customPrint('Audio dispose error: $e');
  }
  // mark ringing stopped so UI dialogs can stop when needed
  try{ Get.find<RingingService>().stopRinging(); }catch(e){ customPrint('RingingService stop not available in this isolate: $e'); }
  return FlutterForegroundTask.stopService();
}

/// Foreground Service entry point
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

/// Foreground Service Task Handler
class MyTaskHandler extends TaskHandler {
  AudioPlayer? _localPlayer;
  int _repeatCount = 0; // safety counter to auto-stop after a period
  static const int _maxRepeats = 12; // 12 * 5s = ~60 seconds

  Future<void> _playAudio() async {
    try {
      await _localPlayer?.setReleaseMode(ReleaseMode.stop);
      await _localPlayer?.play(AssetSource('assets/notification.mp3'));
    } catch(e) {
      customPrint('Error playing audio: $e');
    }
  }
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _localPlayer = AudioPlayer();
    _repeatCount = 0;
    _playAudio();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Auto-stop after ~1 minute in case a closing event was missed
    if (_repeatCount >= _maxRepeats) {
      FlutterForegroundTask.stopService();
      return;
    }
    _repeatCount++;
    // calling _playAudio when using loop is redundant but safe; it will restart playback
    _playAudio();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _localPlayer?.dispose();
    // Do not call stopService() here; onDestroy is invoked by stop already.
  }

  @override
  void onReceiveData(Object data) {
    _playAudio();
  }

  @override
  void onNotificationButtonPressed(String id) {
    customPrint('onNotificationButtonPressed: $id');
    if (id == '1') {
      FlutterForegroundTask.launchApp('/');
    }
    FlutterForegroundTask.stopService();
  }

  @override
  void onNotificationPressed() {
    customPrint('onNotificationPressed');
    FlutterForegroundTask.launchApp('/');
    FlutterForegroundTask.stopService();
  }

  @override
  void onNotificationDismissed() {
    FlutterForegroundTask.updateService(
      notificationTitle: 'You got a new order!',
      notificationText: 'Open app and check order details.',
    );
  }
}