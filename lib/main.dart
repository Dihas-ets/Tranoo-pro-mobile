import 'dart:convert';
import 'dart:core';

import 'package:device_preview/device_preview.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart' as flutter_html;
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/data/screens/avant_home.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/services/blocked_user_service.dart';
import 'package:tranoo_pro/services/push_otp_service.dart';
import 'package:tranoo_pro/utils/local_notification_service.dart';
import 'package:tranoo_pro/providers/locale_provider.dart';

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

      // Gestionnaire pour les notifications cliquées
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _logger.info('Notification cliquée: ${message.notification?.title}');
        _handleNotificationTap(message);
      });

      // Cas app fermée/tuée: notification cliquée
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _logger.info('Initial message (app lancée via notif): ${initialMessage.messageId}');
        _handleNotificationTap(initialMessage);
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

  void _showLocalNotification(RemoteMessage message) {
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
      LocalNotificationService.showNotification(
        message.notification?.title ?? 'Tranoo',
        message.notification?.body ?? '',
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Navigation vers une page spécifique selon le type de notification
    _logger.info(
      'Gestion du tap sur notification: ${message.notification?.title}',
    );

    // Navigation selon le type de notification
    if (message.data.containsKey('type')) {
      switch (message.data['type']) {
        case 'tricycle':
          // Ouvrir la page chauffeur tricycle, avec le contact concerné
          final contactId = message.data['contactId'];
          _logger.info('Navigation vers ChauffeurTricycleHome pour contact $contactId');
          NotificationService.navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) =>
                  ChauffeurTricycleHomePage(initialContactId: contactId),
            ),
          );
          break;
        case 'publicite':
          _logger.info('Navigation vers publicités');
          break;
        case 'article':
          _logger.info('Navigation vers articles');
          break;
        case 'system':
          _logger.info('Notification système: ${message.notification?.body}');
          break;
        default:
          _logger.info('Navigation par défaut');
          break;
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (e) {
    print('Erreur SystemChrome: $e');
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          try {
            return myauth.AuthProvider();
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
      title: 'Tranoo',
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationService.navigatorKey,
      locale: localeProvider.locale ?? DevicePreview.locale(context),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        // Définir le contexte pour BlockedUserService
        WidgetsBinding.instance.addPostFrameCallback((_) {
          BlockedUserService.setContext(context);
        });
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(),
          child: DevicePreview.appBuilder(context, child),
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AppInitializer(),
      routes: {
        '/marque': (context) => const Marque(),
        '/verification-success': (context) => _buildVerificationSuccessPage(),
        '/verification-error': (context) => _buildVerificationErrorPage(),
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

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _carController;
  late final Animation<double> _carOffset;

  @override
  void initState() {
    super.initState();
    _carController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _carOffset = Tween<double>(begin: -0.3, end: 0.3).animate(
      CurvedAnimation(parent: _carController, curve: Curves.easeInOut),
    );
    _carController.repeat(reverse: true);
    _checkUserStatus();
  }

  @override
  void dispose() {
    _carController.dispose();
    super.dispose();
  }

  Future<void> _checkUserStatus() async {
    // Attendre un peu pour que le contexte soit disponible
    await Future.delayed(const Duration(milliseconds: 500));

    // Définir le contexte pour BlockedUserService
    BlockedUserService.setContext(context);

    // Vérifier le statut de blocage
    final userService = UserService();
    final isBlocked = await userService.checkUserBlockedStatus();

    if (isBlocked) {
      // L'utilisateur est bloqué, le dialogue sera affiché automatiquement
      return;
    }

    // Détecter le code de parrainage depuis l'URL
    await _handleReferralCode();

    // Naviguer vers l'écran principal
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AvantHome()),
      );
    }
  }

  Future<void> _handleReferralCode() async {
    try {
      // Vérifier s'il y a un code de parrainage en attente
      final prefs = await SharedPreferences.getInstance();
      final pendingReferral = prefs.getString('pending_referral');

      if (pendingReferral != null && pendingReferral.isNotEmpty) {
        print('Code de parrainage en attente: $pendingReferral');

        // Afficher une notification HTML standard
        if (mounted) {
          _showReferralNotification(pendingReferral);
        }
      }
    } catch (e) {
      print('Erreur lors de la détection du parrainage: $e');
    }
  }

  void _showReferralNotification(String referralCode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.amber[700], size: 28),
              SizedBox(width: 10),
              Text(
                'Code de Parrainage Détecté',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          content: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.celebration,
                        color: Colors.amber[700],
                        size: 40,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Félicitations !',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vous avez été invité par un ami avec le code:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[700],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          referralCode,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  'Ce code sera automatiquement appliqué lors de votre inscription.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Compris',
                style: TextStyle(
                  color: Colors.amber[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  child: Image.asset(
                    'assets/images/logo_tramoo.png',
                    width: size.width * 0.4,
                    cacheWidth: (size.width * 0.4).toInt(),
                    filterQuality: FilterQuality.low,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tranoo Pro',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: size.height * 0.18,
            left: 0,
            right: 0,
            child: SizedBox(
              height: size.height * 0.16,
              child: AnimatedBuilder(
                animation: _carController,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(_carOffset.value * size.width, 0),
                    child: Icon(
                      Icons.directions_car,
                      size: size.width * 0.2,
                      color: Colors.black,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.08,
            left: size.width * 0.2,
            right: size.width * 0.2,
            child: const LinearProgressIndicator(
              backgroundColor: Colors.grey,
              color: Colors.black87,
              minHeight: 4,
            ),
          ),
        ],
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
