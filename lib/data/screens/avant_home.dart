import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tranoo_pro/data/screens/wallet_screen.dart';
import 'package:tranoo_pro/data/screens/marque.dart';
import 'package:tranoo_pro/data/screens/notifications.dart';
import 'package:tranoo_pro/data/screens/piece.dart';
import 'package:tranoo_pro/data/screens/profile.dart';
import 'package:tranoo_pro/data/screens/transitaire_home.dart';
import 'package:tranoo_pro/data/screens/seller_subscription_page.dart';
import 'package:tranoo_pro/data/screens/transit.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
// import 'package:tranoo_pro/data/screens/une.dart'; // Masqué temporairement (onglet Publicité)
import 'package:tranoo_pro/data/screens/voitures.dart';
import 'package:tranoo_pro/data/screens/motos.dart';

import 'package:provider/provider.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;
import 'package:tranoo_pro/providers/counter_provider.dart';

import 'connexion_page.dart';
import 'package:tranoo_pro/data/screens/second_page.dart';
import 'package:tranoo_pro/data/screens/une.dart';
import 'package:tranoo_pro/data/screens/chauffeur_home.dart';
import 'package:tranoo_pro/data/screens/profilutilisateurpage.dart';
import 'package:tranoo_pro/data/screens/profil_utilisateur2.dart';
import 'package:tranoo_pro/data/screens/profil3.dart';
import 'package:tranoo_pro/data/screens/settings_type_vendeur_page.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/utils/auth_dialog.dart';
import 'package:tranoo_pro/utils/page_refresh_registry.dart';
import 'package:tranoo_pro/main.dart' show NotificationService;
import 'package:tranoo_pro/widgets/alert_incoming_call_overlay.dart';
import 'package:tranoo_pro/widgets/alert_display_permission_dialog.dart';
import 'package:tranoo_pro/data/screens/transitaire_verification_page.dart';
import 'package:tranoo_pro/services/transitaire_access_service.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';

class AvantHome extends StatefulWidget {
  const AvantHome({super.key});

  @override
  State<AvantHome> createState() => _AvantHomeState();
}

class _AvantHomeState extends State<AvantHome>
    with WidgetsBindingObserver, RegisterPageRefresh {
  @override
  Future<void> onPagePullRefresh() async => _runLightRefresh(force: true);
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _didCheckOnboarding = false;
  bool _didCheckTypeVendeurMigration = false;
  bool _didCheckTransitaireAccess = false;
  bool _transitaireAccessLoading = false;
  TransitaireAccessState? _transitaireAccess;
  final TransitaireAccessService _transitaireAccessService =
      TransitaireAccessService();
  Timer? _lightRefreshTimer;
  DateTime? _lastLightRefreshAt;
  List<Widget>? _tabPages;
  String? _tabPagesRoleKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runLightRefresh(force: true);
      AlertIncomingCallService.tryShowFromAppLaunchOnly(
        navigatorKey: NotificationService.navigatorKey,
      );
      AlertDisplayPermissionDialog.showIfNeeded(context);
    });
    _lightRefreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _runLightRefresh(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lightRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runLightRefresh(force: true);
      AlertDisplayPermissionDialog.showIfNeeded(context);
      if (mounted) {
        final role = Provider.of<myauth.AuthProvider>(context, listen: false)
            .user?['role'] as String?;
        if (role == 'transitaire') {
          _loadTransitaireAccess(force: true);
        }
      }
    }
  }

  Future<void> _runLightRefresh({bool force = false}) async {
    if (!mounted) return;
    final now = DateTime.now();
    if (!force &&
        _lastLightRefreshAt != null &&
        now.difference(_lastLightRefreshAt!) < const Duration(seconds: 45)) {
      return;
    }
    _lastLightRefreshAt = now;
    try {
      await Provider.of<CounterProvider>(context, listen: false).loadCounters();
    } catch (_) {}
  }

  Future<void> _checkOnboardingAndInactivity() async {
    if (_didCheckOnboarding) return;
    _didCheckOnboarding = true;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!hasSeenOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SecondPage()),
          (route) => false,
        );
      });
      return;
    }
  }

  Future<void> _updateLastLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastLoginTime', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _loadTransitaireAccess({bool force = false}) async {
    if (!mounted) return;
    setState(() => _transitaireAccessLoading = true);
    try {
      final state = await _transitaireAccessService.fetchAccessState();
      if (!mounted) return;
      setState(() => _transitaireAccess = state);
    } catch (_) {
      if (!mounted) return;
      setState(() => _transitaireAccess = null);
    } finally {
      if (mounted) setState(() => _transitaireAccessLoading = false);
    }
  }

  void _onItemTapped(int index, String? role) {
    if (role == 'transitaire' &&
        _transitaireAccess?.subscriptionExpiredRedirect == true &&
        index != 3) {
      showTranooToast(
        context,
        message: AppLocalizations.of(context)!.transitaireSubscriptionExpiredToast,
        isError: true,
      );
      setState(() {
        _selectedIndex = 1;
      });
      return;
    }
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildAnimatedTabBody(List<Widget> pages) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < pages.length; i++)
          IgnorePointer(
            ignoring: _selectedIndex != i,
            child: AnimatedOpacity(
              opacity: _selectedIndex == i ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: TickerMode(
                enabled: _selectedIndex == i,
                child: pages[i],
              ),
            ),
          ),
      ],
    );
  }

  String _roleKeyForUser(Map<String, dynamic>? user) {
    final role = (user?['role'] ?? user?['typeUtilisateur'] ?? user?['type'])
        ?.toString()
        .toLowerCase();
    if (role == 'vendeur') {
      final userService = UserService();
      return 'vendeur_${userService.vendeurType ?? 'mixte'}';
    }
    return role ?? 'guest';
  }

  List<Widget> _pagesForUser(Map<String, dynamic>? user) {
    final role = (user?['role'] ?? user?['typeUtilisateur'] ?? user?['type'])
        ?.toString()
        .toLowerCase();
    final roleKey = _roleKeyForUser(user);
    // Legacy livreur accounts: Accueil + Profil (no dedicated livreur UI).
    if (role == 'livreur') {
      return [
        Marque(key: ValueKey('home_marque_$roleKey')),
        const Profil3(),
      ];
    }
    if (role == 'chauffeur') return _pagesChauffeur;
    if (role == 'transitaire') return _pagesTransitaire;
    if (role == 'vendeur') return _buildVendeurPages(roleKey);
    // ValueKey : force un nouvel State Marque au login (évite skeleton / tabs figés).
    return [
      Marque(key: ValueKey('home_marque_$roleKey')),
      const Profil3(),
    ];
  }

  List<Widget> _resolveTabPages(Map<String, dynamic>? user) {
    final roleKey = _roleKeyForUser(user);
    if (_tabPages != null && _tabPagesRoleKey == roleKey) {
      return _tabPages!;
    }
    _tabPagesRoleKey = roleKey;
    _tabPages = _pagesForUser(user);
    if (_selectedIndex >= _tabPages!.length) {
      _selectedIndex = 0;
    }
    return _tabPages!;
  }

  final List<Widget> _pagesChauffeur = [
    const ChauffeurHomePage(),
    const Profile(),
  ];

  final List<Widget> _pagesTransitaire = [
    const TransitaireHome(),
    const SellerSubscriptionPage(forTransitaire: true),
    const Transit(),
    const ProfilUtilisateur2(),
  ];

  List<Widget> _buildVendeurPages(String roleKey) {
    final userService = UserService();
    final pages = <Widget>[
      Marque(key: ValueKey('home_marque_$roleKey')),
      const Une(isStandalone: true),
    ];
    if (userService.peutVendreVehicules) {
      pages.add(const VoituresPage());
    }
    if (userService.peutVendreMotos) {
      pages.add(const MotosPage());
    }
    if (userService.peutVendrePieces) {
      pages.add(Piece());
    }
    return pages;
  }

  double responsiveSize(
    double screenWidth,
    double smallSize,
    double largeSize,
  ) {
    return screenWidth < 600 ? smallSize : largeSize;
  }

  void _showAvatarDialog(String? photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
        return Dialog(
          backgroundColor: Colors.black,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                  child: hasPhoto
                      ? null
                      : const Icon(
                          Icons.person_outline,
                          size: 80,
                          color: Colors.white70,
                        ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.close,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profilePageForRole(String? role) {
    final normalized = role?.toLowerCase();
    if (normalized == 'vendeur') return const ProfilUtilisateurPage();
    if (normalized == 'transitaire') return const ProfilUtilisateur2();
    if (normalized == 'acheteur') return const Profil3();
    return const Profile();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isPortrait = mediaQuery.orientation == Orientation.portrait;
    final appBarHeight = screenHeight * (isPortrait ? 0.08 : 0.12);
    final iconSize = responsiveSize(screenWidth, 24, 32);
    final logoHeight = screenHeight * (isPortrait ? 0.04 : 0.06);
    final drawerHeaderHeight = screenHeight * (isPortrait ? 0.28 : 0.35);
    final avatarRadius = screenWidth * (isPortrait ? 0.13 : 0.09);
    final spacing = screenHeight * (isPortrait ? 0.01 : 0.02);
    final fontSize = responsiveSize(screenWidth, 14, 18);

    return Consumer<myauth.AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        final role = user != null ? user['role'] as String? : null;
        final pages = _resolveTabPages(user);

        if (user != null) {
          _updateLastLoginTime();
        }

        if (!_didCheckOnboarding) {
          _checkOnboardingAndInactivity();
        }

        if (user == null) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF8BF13),
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (user != null &&
            role == 'vendeur' &&
            !_didCheckTypeVendeurMigration) {
          _didCheckTypeVendeurMigration = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Provider.of<myauth.AuthProvider>(
              context,
              listen: false,
            ).checkTypeVendeurMigration(context);
          });
        }

        final vendeurItemsCount = role == 'vendeur'
            ? _buildVendeurMenuItems(role, iconSize, l10n).length
            : 0;
        if (role == 'vendeur' &&
            vendeurItemsCount > 0 &&
            _selectedIndex > vendeurItemsCount - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedIndex = vendeurItemsCount - 1;
            });
          });
        }

        if (role == 'transitaire' &&
            _selectedIndex > _pagesTransitaire.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedIndex = _pagesTransitaire.length - 1;
            });
          });
        }

        if (user != null &&
            role == 'transitaire' &&
            !_didCheckTransitaireAccess) {
          _didCheckTransitaireAccess = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadTransitaireAccess(force: true);
          });
        }

        if (user != null &&
            role == 'transitaire' &&
            _transitaireAccess != null &&
            _transitaireAccess!.needsVerificationBlock) {
          return TransitaireVerificationPage(
            initialState: _transitaireAccess,
            onAccessChanged: () => _loadTransitaireAccess(force: true),
          );
        }

        if (user != null &&
            role == 'transitaire' &&
            _transitaireAccess != null &&
            _transitaireAccess!.needsSubscriptionBlock) {
          return SellerSubscriptionPage(
            forTransitaire: true,
            blockerMode: true,
            onSubscriptionChanged: () => _loadTransitaireAccess(force: true),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            backgroundColor: const Color(0xFFF9FAFB),
            elevation: 0,
            toolbarHeight: appBarHeight,
            title: Center(
              child: Image.asset(
                "assets/images/logo_connexion.png",
                height: logoHeight + 6,
              ),
            ),
            actions: [
              Consumer<CounterProvider>(
                builder: (context, counter, child) {
                  return IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.notifications_none_outlined,
                          color: Colors.black,
                          size: iconSize,
                        ),
                        if (counter.unreadNotificationsCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                counter.unreadNotificationsCount > 99
                                    ? '99+'
                                    : counter.unreadNotificationsCount
                                        .toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Notifications(),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
            leading: IconButton(
              icon: Icon(Icons.menu, color: Colors.black, size: iconSize),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
          ),
          body: _buildAnimatedTabBody(pages),
          drawer: Drawer(
            child: user == null
                ? Center(child: Text(l10n.userNotConnected))
                : Column(
                        children: [
                          // Header fixe
                          Container(
                            width: double.infinity,
                            height: drawerHeaderHeight + 20,
                            padding: EdgeInsets.zero,
                            margin: EdgeInsets.zero,
                            decoration: const BoxDecoration(
                              color: Color(0XffF8BF13),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Builder(builder: (context) {
                                  final photoUrl =
                                      (user['photo'] as String?) ?? '';
                                  final hasPhoto = photoUrl.isNotEmpty;
                                  return GestureDetector(
                                    onTap: () => _showAvatarDialog(photoUrl),
                                    child: CircleAvatar(
                                      radius: avatarRadius,
                                      backgroundColor: Colors.grey[300],
                                      backgroundImage: hasPhoto
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: !hasPhoto
                                          ? Icon(
                                              Icons.person_outline,
                                              size: avatarRadius * 0.9,
                                              color: Colors.grey[700],
                                            )
                                          : null,
                                    ),
                                  );
                                }),
                                SizedBox(height: spacing),
                                Text(
                                  user['nom'] ?? l10n.user,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  user['email'] ?? "",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fontSize * 0.8,
                                  ),
                                ),
                                if (user['role'] != null)
                                  Text(
                                    (user['role'] as String).toUpperCase(),
                                    style: TextStyle(
                                      color: const Color(0xFF0A1F44),
                                      fontSize: fontSize * 0.75,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Liste scrollable
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _buildDrawerButton(
                                  context,
                                  text: l10n.home,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AvantHome(),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.home,
                                    color: Colors.black,
                                    size: iconSize,
                                  ),
                                ),
                                _buildDrawerButton(
                                  context,
                                  text: l10n.profile,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          _profilePageForRole(role),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.person_outline,
                                    color: Colors.black,
                                    size: iconSize,
                                  ),
                                ),
                                if (role != 'vendeur' && role != 'transitaire')
                                  _buildDrawerButton(
                                    context,
                                    text: l10n.myWallet,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const WalletScreen(),
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.account_balance_wallet,
                                      color: Colors.black,
                                      size: iconSize,
                                    ),
                                  ),
                                if (role == 'vendeur')
                                  _buildDrawerButton(
                                    context,
                                    text: l10n.sellerTypeLabel,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SettingsTypeVendeurPage(),
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.category,
                                      color: Colors.black,
                                      size: iconSize,
                                    ),
                                  ),
                                _buildDrawerButton(
                                  context,
                                  text: l10n.logout,
                                  onTap: () async {
                                    Navigator.pop(context);
                                    final confirm =
                                        await showLogoutConfirmationDialog(
                                      context,
                                    );
                                    if (confirm != true || !context.mounted) {
                                      return;
                                    }
                                    await Provider.of<myauth.AuthProvider>(
                                      context,
                                      listen: false,
                                    ).logout();
                                    if (!context.mounted) return;
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ConnexionPage(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                  icon: Icon(
                                    Icons.logout,
                                    color: Colors.black,
                                    size: iconSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
          bottomNavigationBar: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: const Color(0xFFF9FAFB),
                  selectedItemColor: const Color(0xFFF8BF13),
                  unselectedItemColor: Colors.black,
                  currentIndex: _selectedIndex,
                  onTap: (i) => _onItemTapped(i, role),
                  items: (role == 'vendeur' ||
                          role?.startsWith('vendeur') == true)
                      ? _buildVendeurMenuItems(role, iconSize, l10n)
                      : role == 'transitaire'
                          ? [
                              BottomNavigationBarItem(
                                icon: Icon(Icons.home_outlined, size: iconSize),
                                label: 'Accueil',
                              ),
                              BottomNavigationBarItem(
                                icon: Icon(Icons.card_membership_outlined,
                                    size: iconSize),
                                label: 'Abonnement',
                              ),
                              BottomNavigationBarItem(
                                icon: Icon(Icons.local_shipping_outlined,
                                    size: iconSize),
                                label: 'Transit',
                              ),
                              BottomNavigationBarItem(
                                icon: Icon(Icons.person_outline, size: iconSize),
                                label: l10n.profile,
                              ),
                            ]
                          : role == 'livreur'
                              ? [
                                  BottomNavigationBarItem(
                                    icon: Icon(Icons.home, size: iconSize),
                                    label: 'Accueil',
                                  ),
                                  BottomNavigationBarItem(
                                    icon: Icon(Icons.person, size: iconSize),
                                    label: 'Profil',
                                  ),
                                ]
                              : role == 'chauffeur'
                                  ? [
                                      BottomNavigationBarItem(
                                        icon: Icon(Icons.home, size: iconSize),
                                        label: 'Accueil',
                                      ),
                                      BottomNavigationBarItem(
                                        icon:
                                            Icon(Icons.person, size: iconSize),
                                        label: 'Profil',
                                      ),
                                    ]
                                  : [
                                      BottomNavigationBarItem(
                                        icon: Icon(Icons.home, size: iconSize),
                                        label: 'Accueil',
                                      ),
                                      BottomNavigationBarItem(
                                        icon:
                                            Icon(Icons.person, size: iconSize),
                                        label: 'Profil',
                                      ),
                                    ],
                ),
        );
      },
    );
  }

  Widget _buildDrawerButton(
    BuildContext context, {
    required String text,
    required Function() onTap,
    required Icon icon,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = responsiveSize(screenWidth, 14, 18);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            children: [
              Icon(icon.icon, color: const Color(0xFFF8BF13), size: icon.size),
              const SizedBox(width: 16),
              Text(
                text,
                style: TextStyle(color: Colors.black, fontSize: fontSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildMotoNavIcon(double size) {
  //   final motoSize = size * 1.25;
  //   return Image.asset(
  //     'assets/images/motorbike.png',
  //     width: motoSize,
  //     height: motoSize,
  //     fit: BoxFit.contain,
  //   );
  // }

  // Menu vendeur dynamique selon vendeurType (motos avant pièces)
  List<BottomNavigationBarItem> _buildVendeurMenuItems(
      String? role, double iconSize, AppLocalizations l10n) {
    final userService = UserService();
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: Icon(Icons.storefront_outlined, size: iconSize),
        label: l10n.shopLabel,
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.campaign, size: iconSize),
        label: l10n.advertisingLabel,
      ),
    ];
    if (userService.peutVendreVehicules) {
      items.add(BottomNavigationBarItem(
        icon: Icon(Icons.directions_car, size: iconSize),
        label: l10n.cars,
      ));
    }
    if (userService.peutVendreMotos) {
      items.add(BottomNavigationBarItem(
        // icon: _buildMotoNavIcon(iconSize),
        icon: const Icon(Icons.motorcycle),
        label: 'Motos',
      ));
    }
    if (userService.peutVendrePieces) {
      items.add(BottomNavigationBarItem(
        icon: Icon(Icons.build, size: iconSize),
        label: l10n.pieces,
      ));
    }
    return items;
  }
}
