import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:device_preview/device_preview.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart' as flutter_html;
import 'package:tranoo_pro/utils/notification_i18n.dart';
import 'package:tranoo_pro/utils/locale_helper.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/data/screens/avant_home.dart';
import 'package:tranoo_pro/services/blocked_user_service.dart';
import 'package:tranoo_pro/services/push_otp_service.dart';
import 'package:tranoo_pro/utils/local_notification_service.dart';
import 'package:tranoo_pro/providers/locale_provider.dart';
import 'package:tranoo_pro/widgets/video_splash_screen.dart';
import 'package:tranoo_pro/services/app_bootstrap.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tranoo_pro/utils/feexpay_choice_callback_page.dart';
import 'package:tranoo_pro/widgets/alert_incoming_call_overlay.dart';
import 'package:tranoo_pro/services/alert_launch_bootstrap.dart';
import 'package:tranoo_pro/data/screens/notifications.dart';
import 'package:tranoo_pro/utils/notification_tap_router.dart';
import 'package:tranoo_pro/services/alert_message_utils.dart';
// import 'package:flutter/services.dart';
import 'package:tranoo_pro/config/backend_config.dart';
import 'package:tranoo_pro/data/screens/marque.dart';
import 'package:tranoo_pro/firebase_options.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;
import 'package:tranoo_pro/providers/counter_provider.dart';
import 'package:tranoo_pro/data/screens/tricycle/chauffeur_tricycle_home.dart';
import 'package:tranoo_pro/services/cart_service.dart';
import 'package:tranoo_pro/data/screens/reset/forgot_password_page.dart';
import 'package:tranoo_pro/data/screens/reset/verify_code_page.dart';
import 'package:tranoo_pro/data/screens/reset/create_new_password_page.dart';

// Gestionnaire pour les notifications en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Logger('FCM').info('Message reçu en arrière-plan: ${message.messageId}');
  if (isAlertFcmMessage(message)) {
    await LocalNotificationService.initialize();
    final locale = await LocaleHelper.storedLanguageCode();
    final push = NotificationI18n.resolvePush(
      message,
      locale,
      defaultTitle: 'Nouvelle alerte Tranoo',
    );
    final data = message.data.map(
      (k, v) => MapEntry(k, v?.toString() ?? ''),
    );
    await LocalNotificationService.showAlertIncomingCallNotification(
      title: push.title,
      body: push.body,
      data: data,
    );
  }
}

// Service pour gérer les notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final Logger _logger = Logger('NotificationService');

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    try {
      // Demander les permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      _logger.info('Permissions accordées: ${settings.authorizationStatus}');

      // Configurer le gestionnaire de messages en arrière-plan
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Gestionnaire pour les messages en premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logger.info(
          'Message reçu en premier plan: ${message.notification?.title}',
        );

        // Alerte : plein écran dans l'app (pas la notif générique)
        if (AlertIncomingCallService.isAlertMessage(message)) {
          AlertIncomingCallService.show(
            message,
            navigatorKey: NotificationService.navigatorKey,
          );
          return;
        }

        _showLocalNotification(message);

        // Tricycle: ouvrir automatiquement le popup (via écran chauffeur)
        if (message.data['type'] == 'tricycle') {
          final contactId = message.data['contactId'];
          if (contactId != null && contactId.toString().isNotEmpty) {
            NotificationService.navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => ChauffeurTricycleHomePage(
                  initialContactId: contactId.toString(),
                ),
              ),
            );
          }
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _logger.info('Notification cliquée: ${message.notification?.title}');
        if (isAlertFcmMessage(message)) {
          _openAlertNotificationFromTap(message);
          return;
        }
        _handleNotificationTap(message);
      });

      // Cas app fermée/tuée: notification cliquée
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _logger.info(
            'Initial message (app lancée via notif): ${initialMessage.messageId}');
        if (isAlertFcmMessage(initialMessage)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openAlertNotificationFromTap(initialMessage);
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleNotificationTap(initialMessage);
          });
        }
      }

      // Récupérer le token FCM
      String? token = await _messaging.getToken();
      if (token != null) {
        _logger.info('Token FCM: $token');
        await _sendTokenToBackend(token);
      }

      // Écouter les changements de token
      _messaging.onTokenRefresh.listen((newToken) {
        _logger.info('Nouveau token FCM: $newToken');
        _sendTokenToBackend(newToken);
      });
    } catch (e) {
      _logger.severe('Erreur lors de l\'initialisation FCM: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        _logger.warning('Utilisateur non connecté, token non envoyé');
        return;
      }

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('${getBackendBaseUrl()}/api/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        _logger.info('Token FCM envoyé au backend avec succès');
      } else {
        _logger.warning(
          'Erreur lors de l\'envoi du token: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.severe('Erreur lors de l\'envoi du token au backend: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) async {
    _logger.info('Notification locale: ${message.notification?.title}');

    // Afficher une notification locale visible même en foreground
    if (message.data['type'] == 'otp') {
      final code = message.data['code'] as String?;
      if (code != null && code.isNotEmpty) {
        LocalNotificationService.showOTPNotification(code);
      } else {
        // Fallback: extraire depuis body
        final body = message.notification?.body ?? '';
        final match = RegExp(r'(\d{6})').firstMatch(body);
        if (match != null) {
          LocalNotificationService.showOTPNotification(match.group(1)!);
        }
      }
    } else {
      final locale = await LocaleHelper.storedLanguageCode();
      final push = NotificationI18n.resolvePush(message, locale);
      if (message.data['type'] == 'tricycle') {
        LocalNotificationService.showTricycleNotification(
          push.title,
          push.body,
        );
      } else {
        LocalNotificationService.showNotification(
          push.title,
          push.body,
          payload: 'fcm:${jsonEncode(message.data)}',
        );
      }
    }
  }

  void _openAlertNotificationFromTap(RemoteMessage message) {
    final type = (message.data['type'] ?? '').toString();
    final action = (message.data['action'] ?? '').toString();
    if (type == 'proposition_alerte' ||
        action == 'view_proposal' ||
        action == 'view_article') {
      _handleNotificationTap(message);
      return;
    }
    final notificationId = message.data['notificationId']?.toString();
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => Notifications(
          openNotificationId:
              (notificationId != null && notificationId.isNotEmpty)
                  ? notificationId
                  : null,
        ),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    _logger.info(
      'Gestion du tap sur notification: ${message.notification?.title}',
    );
    NotificationTapRouter.openFromRemoteMessage(
      NotificationService.navigatorKey.currentContext,
      message,
      navigatorKey: NotificationService.navigatorKey,
    );
  }
}

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (e) {
    print('Erreur SystemChrome: $e');
  }

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    print('Firebase initialisé avec succès');
  } catch (e, stackTrace) {
    print('ERREUR Firebase initialization: $e');
    print('Stack trace: $stackTrace');
    // Continuer même si Firebase échoue pour voir où ça bloque
  }

  // Charger les variables d'environnement
  try {
    await dotenv.load(fileName: ".env");
    print('Fichier .env chargé');
  } catch (e) {
    print('Avertissement: Fichier .env non trouvé ou erreur: $e');
    // Continuer sans .env si ce n'est pas critique
  }

  // Initialiser le service de notifications locales
  try {
    await LocalNotificationService.initialize();
    print('LocalNotificationService initialisé');
  } catch (e) {
    print('Erreur LocalNotificationService: $e');
  }

  // Initialiser le service de notifications
  try {
    await NotificationService().initialize();
    print('NotificationService initialisé');
  } catch (e) {
    print('Erreur NotificationService: $e');
    // Continuer même si les notifications échouent
  }

  // Initialiser le service OTP Push
  try {
    await PushOTPService.initialize();
    print('PushOTPService initialisé');
  } catch (e) {
    print('Erreur PushOTPService: $e');
    // Continuer même si OTP Push échoue
  }

  await AppBootstrap.warmUp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          try {
            return myauth.AuthProvider(
              initialUser: AppBootstrap.cachedUser,
              initialToken: AppBootstrap.cachedToken,
            );
          } catch (e) {
            print('ERREUR AuthProvider: $e');
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) => CounterProvider()),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    return MaterialApp(
      title: 'Tranoo Pro',
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationService.navigatorKey,
      locale: localeProvider.locale ?? DevicePreview.locale(context),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          BlockedUserService.setContext(context);
        });
        return AlertLaunchBootstrap(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(),
            child: DevicePreview.appBuilder(context, child),
          ),
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        useMaterial3: true,
      ),
      home: const SplashFlow(),
      routes: {
        '/marque': (context) => const Marque(),
        '/payment-success': (context) =>
            const FeexPayChoiceCallbackPage(success: true),
        '/payment-error': (context) =>
            const FeexPayChoiceCallbackPage(success: false),
        '/subscription-success': (context) =>
            const FeexPayChoiceCallbackPage(success: true),
        '/subscription-error': (context) =>
            const FeexPayChoiceCallbackPage(success: false),
        '/cart-payment-success': (context) =>
            const FeexPayChoiceCallbackPage(success: true),
        '/cart-payment-error': (context) =>
            const FeexPayChoiceCallbackPage(success: false),
        '/verification-success': (context) =>
            const FeexPayChoiceCallbackPage(success: true),
        '/verification-error': (context) =>
            const FeexPayChoiceCallbackPage(success: false),
        '/auth/forgot-password': (context) => const ForgotPasswordPage(),
        '/auth/verify-reset': (context) => const VerifyResetCodePage(),
        '/auth/create-password': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CreateNewPasswordPage(
            requestId: args?['requestId'] ?? '',
            deviceId: args?['deviceId'] ?? '',
          );
        },
      },
    );
  }
}

// Gestion du succès de paiement de vérification
Widget _buildVerificationSuccessPage() {
  return VerificationSuccessPage();
}

// Gestion de l'échec de paiement de vérification
Widget _buildVerificationErrorPage() {
  return VerificationErrorPage();
}

class VerificationSuccessPage extends StatefulWidget {
  @override
  _VerificationSuccessPageState createState() =>
      _VerificationSuccessPageState();
}

class _VerificationSuccessPageState extends State<VerificationSuccessPage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String? htmlContent;

  @override
  void initState() {
    super.initState();
    _loadAndShow();
  }

  Future<void> _loadAndShow() async {
    try {
      htmlContent = await DefaultAssetBundle.of(context)
          .loadString('assets/html/verification_success.html');
    } catch (_) {
      htmlContent = null;
    }
    setState(() {});
    await Future.delayed(const Duration(seconds: 2));
    if (mounted)
      Navigator.of(context).pop(true); // retourner à l'écran appelant
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: htmlContent != null
              ? SingleChildScrollView(
                  child: flutter_html.Html(data: htmlContent))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 64),
                    SizedBox(height: 16),
                    Text('Paiement réussi',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Redirection en cours...',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
        ),
      ),
    );
  }
}

class VerificationErrorPage extends StatefulWidget {
  @override
  State<VerificationErrorPage> createState() => _VerificationErrorPageState();
}

class _VerificationErrorPageState extends State<VerificationErrorPage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String? htmlContent;

  @override
  void initState() {
    super.initState();
    _loadAndShow();
  }

  Future<void> _loadAndShow() async {
    try {
      htmlContent = await DefaultAssetBundle.of(context)
          .loadString('assets/html/verification_error.html');
    } catch (_) {
      htmlContent = null;
    }
    setState(() {});
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: htmlContent != null
              ? SingleChildScrollView(
                  child: flutter_html.Html(data: htmlContent))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.error, color: Colors.red, size: 64),
                    SizedBox(height: 16),
                    Text('Paiement échoué',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Redirection en cours...',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
        ),
      ),
    );
  }
}

class SplashFlow extends StatefulWidget {
  const SplashFlow({super.key});

  @override
  State<SplashFlow> createState() => _SplashFlowState();
}

class _SplashFlowState extends State<SplashFlow> {
  bool _showApp = false;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _goToApp();
  }

  Future<void> _goToApp() async {
    try {
      final dest = await AppBootstrap.resolveEntryWidget(context);
      if (!mounted) return;
      FlutterNativeSplash.remove();
      setState(() {
        _destination = dest;
        _showApp = true;
      });
    } catch (_) {
      if (!mounted) return;
      FlutterNativeSplash.remove();
      setState(() {
        _destination = AppBootstrap.fallbackEntry();
        _showApp = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showApp) {
      return _destination ?? AppBootstrap.fallbackEntry();
    }
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF1B2B4B),
          ),
        ),
      ),
    );
  }
}

/*void main() {
  runApp(const MyApp());
}*/

/*class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FirstPage(),
    );
  }
}*/

// import 'package:flutter/material.dart';
// import 'nouveau.dart'; // adapte le chemin si besoin

// void main() {
//   runApp(const MaterialApp(
//     home: AgePickerPage(),
//     debugShowCheckedModeBanner: false,
//   ));
// }
