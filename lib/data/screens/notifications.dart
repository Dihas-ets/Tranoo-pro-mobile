import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/user_service.dart';
import '../../providers/counter_provider.dart';
import 'create_sell.dart';
import 'create_sell2.dart';
import 'cars_info.dart';
import 'mastervacpage.dart';
import 'package:tranoo_pro/widgets/notification_list_ui.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

// --------- HELPERS SÉCURISÉS ----------
List<String> getNotifImages(Map notif) {
  try {
    final att = notif['attachments'];
    if (att == null || att is! Map) return [];

    final imgs = att['images'];
    if (imgs == null) return [];

    if (imgs is List) {
      return imgs.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (imgs is String) return [imgs];
    return [];
  } catch (e) {
    print('Erreur getNotifImages: $e');
    return [];
  }
}

List<String> getNotifDocuments(Map notif) {
  try {
    final att = notif['attachments'];
    if (att == null || att is! Map) return [];

    final docs = att['documents'];
    if (docs == null) return [];

    if (docs is List) {
      return docs.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (docs is String) return [docs];
    return [];
  } catch (e) {
    print('Erreur getNotifDocuments: $e');
    return [];
  }
}

String? getStampUrl(Map notif) {
  try {
    final att = notif['attachments'];
    if (att == null || att is! Map) return null;

    final val = att['stampUrl'];
    if (val is String && val.isNotEmpty) return val;
    return null;
  } catch (e) {
    print('Erreur getStampUrl: $e');
    return null;
  }
}

String? getSignatureUrl(Map notif) {
  try {
    final att = notif['attachments'];
    if (att == null || att is! Map) return null;

    final val = att['signatureUrl'];
    if (val is String && val.isNotEmpty) return val;
    return null;
  } catch (e) {
    print('Erreur getSignatureUrl: $e');
    return null;
  }
}

// ------------- PAGE DÉTAIL VÉRIFICATION ------------------
class VerificationDetailPage extends StatelessWidget {
  final Map<String, dynamic> notification;
  const VerificationDetailPage({Key? key, required this.notification})
      : super(key: key);

  Future<void> _postVerificationAction(
      BuildContext context, String action) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final notificationId = _safeGetStringLocal(notification, '_id');
      if (token == null || notificationId == null) return;
      final resp = await http.post(
        Uri.parse(
            '${getBaseUrl()}/notifications/$notificationId/verification-action'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'action': action}),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        // OK
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur action: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  static String? _safeGetStringLocal(dynamic obj, String key) {
    try {
      if (obj is Map && obj.containsKey(key)) {
        final val = obj[key];
        if (val is String) return val;
        if (val != null) return val.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final images = getNotifImages(notification);
    final documents = getNotifDocuments(notification);
    final stampUrl = getStampUrl(notification);
    final signatureUrl = getSignatureUrl(notification);
    final bodyHtml = _safeGetStringLocal(notification, 'bodyHtml') ??
        _safeGetStringLocal(notification, 'message') ??
        '-';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber[100],
        foregroundColor: Colors.black,
        title: const Text('Détail de la vérification',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0.7,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SvgPicture.asset('assets/images/logo_tramoo.svg', height: 54),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Destinataire',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13)),
                    Text(
                        _safeGetStringLocal(notification['recipient'], 'nom') ??
                            '-',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      _safeGetStringLocal(notification['recipient'], 'email') ??
                          _safeGetStringLocal(
                              notification['recipient'], 'telephone') ??
                          '-',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        notification['date'] is DateTime
                            ? _formatDateStatic(notification['date'])
                            : '',
                        style: const TextStyle(fontSize: 13))
                  ],
                ),
              ],
            ),
            const Divider(height: 36),
            Text(_safeGetStringLocal(notification, 'title') ?? '',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                    color: Colors.amber[900])),
            if (_safeGetStringLocal(notification, 'details') != null) ...[
              const SizedBox(height: 6),
              Text(_safeGetStringLocal(notification, 'details')!,
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ],
            const SizedBox(height: 10),
            Html(data: bodyHtml),
            if (documents.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Documents joints',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: documents.map((url) {
                  final name = url.split('/').last.split('?').first;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        try {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Impossible d\'ouvrir le document'),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.insert_drive_file, size: 18),
                      label: Text(
                        name,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  mainAxisSpacing: 11,
                  crossAxisSpacing: 11,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _safeMapImages(images),
                ),
              ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (stampUrl != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Image.network(stampUrl,
                      height: 53,
                      width: 53,
                      fit: BoxFit.contain,
                      opacity: const AlwaysStoppedAnimation(0.9),
                      errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 53,
                      width: 53,
                      color: Colors.grey[300],
                      child: const Icon(Icons.verified, color: Colors.amber),
                    );
                  }),
                ),
              if (signatureUrl != null)
                Image.network(signatureUrl, height: 39, fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 39,
                    width: 100,
                    color: Colors.grey[300],
                    child: const Icon(Icons.edit, color: Colors.blueGrey),
                  );
                }),
            ]),
            const SizedBox(height: 16),
            if ((_safeGetStringLocal(notification, 'status') ?? 'pending') ==
                'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await _postVerificationAction(context, 'approve');
                      String? articleId = _safeGetStringLocal(
                          notification['verificationData'], 'articleId');
                      articleId ??= _safeGetStringLocal(
                              notification['relatedId'], '_id') ??
                          _safeGetStringLocal(notification, 'relatedId');
                      if (articleId != null && articleId.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Cette fonctionnalité n\'est plus disponible'),
                          ),
                        );
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Article introuvable')),
                        );
                        Navigator.pop(context);
                      }
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: Text(l10n.validate,
                        style: TextStyle(color: Colors.black)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _postVerificationAction(context, 'reject');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.requestRejected)),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[300]),
                    child: const Text('Rejeter',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDateStatic(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return 'Il y a ${diff.inDays} jours';
    if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inMinutes} minutes';
  }

  static List<Widget> _safeMapImages(List<String> images) {
    try {
      return images
          .map((img) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  img,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 90,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    );
                  },
                ),
              ))
          .toList();
    } catch (e) {
      print('Erreur _safeMapImages: $e');
      return [];
    }
  }
}

class NotificationProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_notifications);
  bool loading = true;

  NotificationProvider() {
    _initFCMListener();
  }

  void addNotification(Map<String, dynamic> notif) {
    _notifications.insert(0, notif);
    notifyListeners();
  }

  Future<void> loadNotificationsFromAPI(String token) async {
    loading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/notifications/'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _notifications.clear();

        final notificationsList = data['notifications'];
        if (notificationsList is List) {
          for (var notif in notificationsList) {
            if (notif is Map) {
              _notifications.add({
                ...notif,
                'date': notif['createdAt'] != null
                    ? DateTime.tryParse(notif['createdAt'].toString()) ??
                        DateTime.now()
                    : DateTime.now(),
              });
            }
          }
        }
        notifyListeners();
      } else {
        print(
            'Erreur lors du chargement des notifications: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Erreur lors du chargement des notifications: $e');
    }
    loading = false;
    notifyListeners();
  }

  Future<void> markNotificationAsRead(String id, String token) async {
    try {
      final response = await http.put(
        Uri.parse('${getBaseUrl()}/notifications/$id/read'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        for (final notif in _notifications) {
          if (notif['_id'] == id) {
            notif['isRead'] = true;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      print('Erreur marquage notification lue: $e');
    }
  }

  Future<void> markNotificationAsUnread(String id, String token) async {
    try {
      final response = await http.put(
        Uri.parse('${getBaseUrl()}/notifications/$id/unread'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        for (final notif in _notifications) {
          if (notif['_id'] == id) {
            notif['isRead'] = false;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      print('Erreur marquage notification non lue: $e');
    }
  }

  Future<void> handleVerificationAction(
    String id,
    String action,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/notifications/$id/verification-action'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"action": action}),
      );
      print("Verification action response: ${response.statusCode}");
    } catch (e) {
      print('Erreur action vérif: $e');
    }
  }

  Future<bool> deleteNotification(String id, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('${getBaseUrl()}/notifications/$id'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        _notifications.removeWhere((n) => (n['_id'] ?? '').toString() == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur suppression notification: $e');
      return false;
    }
  }

  void _initFCMListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = {
        'id': message.messageId ?? DateTime.now().toIso8601String(),
        'title': message.notification?.title ?? 'Notification',
        'message': message.notification?.body ?? '',
        'date': DateTime.now(),
        'isRead': false,
        'type': message.data['type'] ?? 'general',
        'actions': message.data['actions'] ?? [],
        'status': message.data['status'] ?? 'pending',
        'verificationData': message.data['verificationData'] ?? {},
      };
      addNotification(notif);
    });
  }
}

class Notifications extends StatelessWidget {
  final String? openNotificationId;

  const Notifications({super.key, this.openNotificationId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider(
      create: (_) => NotificationProvider(),
      child: NotificationsBody(openNotificationId: openNotificationId),
    );
  }
}

class NotificationsBody extends StatefulWidget {
  final String? openNotificationId;

  const NotificationsBody({super.key, this.openNotificationId});

  @override
  State<NotificationsBody> createState() => _NotificationsBodyState();
}

class _NotificationsBodyState extends State<NotificationsBody> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final Set<String> _selectedNotificationIds = <String>{};

  bool get _selectionMode => _selectedNotificationIds.isNotEmpty;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedNotificationIds.contains(id)) {
        _selectedNotificationIds.remove(id);
      } else {
        _selectedNotificationIds.add(id);
      }
    });
  }

  void _clearSelection() {
    if (!_selectionMode) return;
    setState(() => _selectedNotificationIds.clear());
  }

  Future<void> _deleteSelected(NotificationProvider provider) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null) return;
    final ids = _selectedNotificationIds.toList();
    for (final id in ids) {
      await provider.deleteNotification(id, token);
    }
    if (!mounted) return;
    _clearSelection();
    _syncUnreadCountWithHeader(provider);
  }

  void _syncUnreadCountWithHeader(NotificationProvider provider) {
    final unreadCount =
        provider.notifications.where((n) => !(n['isRead'] ?? false)).length;
    Provider.of<CounterProvider>(
      context,
      listen: false,
    ).updateNotificationsCount(unreadCount);
  }

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      user.getIdToken().then((token) {
        if (token != null) {
          provider.loadNotificationsFromAPI(token).then((_) {
            if (!mounted) return;
            _syncUnreadCountWithHeader(provider);
            _openPendingNotificationIfNeeded(provider, token);
          });
        }
      });
    } else {
      print(
          'Aucun utilisateur connecté. Impossible de charger les notifications.');
    }
  }

  void _openPendingNotificationIfNeeded(
    NotificationProvider provider,
    String token,
  ) {
    final pendingId = widget.openNotificationId;
    if (pendingId == null || pendingId.isEmpty || !mounted) return;
    Map<String, dynamic>? target;
    for (final n in provider.notifications) {
      if ((n['_id'] ?? '').toString() == pendingId) {
        target = Map<String, dynamic>.from(n);
        break;
      }
    }
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showNotificationDetail(context, target!, provider, token);
    });
  }

  Future<void> _handleAlertMenuAction({
    required String action,
    required Map<String, dynamic> notif,
    required NotificationProvider provider,
  }) async {
    final notifId = (_safeGetString(notif, '_id') ?? '').toString();
    if (notifId.isEmpty) return;
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return;

    if (action == 'delete') {
      final ok = await provider.deleteNotification(notifId, token);
      if (!mounted) return;
      if (ok) {
        _syncUnreadCountWithHeader(provider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.notificationDeleted)),
        );
      }
      return;
    }

    if (action == 'unread') {
      await provider.markNotificationAsUnread(notifId, token);
      if (!mounted) return;
      _syncUnreadCountWithHeader(provider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.markedAsUnread)),
      );
    }
  }

  void _showImageFullscreen(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<NotificationProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                tooltip: 'Annuler',
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        title: Text(
          _selectionMode
              ? '${_selectedNotificationIds.length} sélectionnée(s)'
              : 'Notifications',
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
        actions: [
          if (_selectionMode)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.delete),
                    content: Text(
                      'Supprimer ${_selectedNotificationIds.length} notification(s) ?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE57373),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(l10n.delete),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await _deleteSelected(provider);
                }
              },
            ),
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.notifications.isEmpty
              ? Center(
                  child: Text(l10n.noNotifications,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final token = await user.getIdToken();
                      if (token != null) {
                        await provider.loadNotificationsFromAPI(token);
                        if (mounted) {
                          _syncUnreadCountWithHeader(provider);
                        }
                      }
                    }
                  },
                  child: _buildNotificationsList(provider, user),
                ),
    );
  }

  Widget _buildNotificationsList(NotificationProvider provider, User? user) {
    try {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        itemCount: provider.notifications.length,
        itemBuilder: (ctx, index) {
          if (index < 0 || index >= provider.notifications.length) {
            return const SizedBox.shrink();
          }

          final notif = provider.notifications[index];
          final isVerification =
              _safeGetString(notif, 'type') == 'verification';
          final isUnread = !(notif['isRead'] ?? false);
          final notifData = (notif['data'] is Map)
              ? Map<String, dynamic>.from(notif['data'])
              : <String, dynamic>{};
          final requestType = (notifData['requestType'] ?? '').toString();
          final isAlert = _safeGetString(notif, 'type') == 'alerte' ||
              requestType == 'vehicle_search' ||
              requestType == 'piece_search';
          final isProposalNotification =
              (notifData['action'] ?? '').toString() == 'view_proposal';
          final proposalThumb = (notifData['thumbnailUrl'] ?? '').toString();
          final proposalTitle = (notifData['articleTitle'] ?? '').toString();
          final notifId = (_safeGetString(notif, '_id') ?? '').toString();
          final isSelected =
              notifId.isNotEmpty && _selectedNotificationIds.contains(notifId);

          Future<void> handleTap() async {
            if (_selectionMode) {
              if (notifId.isNotEmpty) _toggleSelection(notifId);
              return;
            }
            if (isVerification) {
              final token = await user?.getIdToken();
              final notificationId = _safeGetString(notif, '_id');
              if (token != null && notificationId != null) {
                await provider.markNotificationAsRead(notificationId, token);
                if (mounted) {
                  _syncUnreadCountWithHeader(provider);
                }
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) =>
                      VerificationDetailPage(notification: notif),
                ),
              );
            } else {
              final token = await user?.getIdToken();
              if (token != null) {
                _showNotificationDetail(context, notif, provider, token);
                if (mounted) {
                  _syncUnreadCountWithHeader(provider);
                }
              }
            }
          }

          return _buildUnifiedNotificationListItem(
            notif: Map<String, dynamic>.from(notif),
            isUnread: isUnread,
            isSelected: isSelected,
            onTap: () => handleTap(),
            onLongPress: () {
              if (notifId.isEmpty) return;
              _toggleSelection(notifId);
            },
            provider: provider,
          );
        },
      );
    } catch (e) {
      print('Erreur _buildNotificationsList: $e');
      return Center(
        child: Text(l10n.notificationsLoadError),
      );
    }
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return 'Il y a ${diff.inDays} jours';
    if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inMinutes} minutes';
  }

  Map<String, dynamic> _notifDataMap(Map<String, dynamic> notif) {
    if (notif['data'] is Map) {
      return Map<String, dynamic>.from(notif['data']);
    }
    return <String, dynamic>{};
  }

  String? _alertImageUrl(Map<String, dynamic> notif) {
    final data = _notifDataMap(notif);
    final thumb = (data['thumbnailUrl'] ?? '').toString();
    if (thumb.isNotEmpty) return thumb;
    final photos = data['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos.first.toString();
    }
    return null;
  }

  String _alertPreviewText(Map<String, dynamic> notif) {
    final data = _notifDataMap(notif);
    final requestType = (data['requestType'] ?? '').toString();
    final isPiece = requestType == 'piece_search';
    final parts = <String>[];
    final marque = (data['marque'] ?? '').toString().trim();
    final modele = (data['modele'] ?? '').toString().trim();
    if (marque.isNotEmpty) parts.add(marque);
    if (modele.isNotEmpty) parts.add(modele);
    if (isPiece) {
      final piece = (data['pieceName'] ?? '').toString().trim();
      if (piece.isNotEmpty) parts.add(piece);
    } else {
      final budget = (data['budget'] ?? data['budgetMax'] ?? '').toString().trim();
      if (budget.isNotEmpty) parts.add('Budget $budget FCFA');
    }
    if (parts.isNotEmpty) return parts.join(' · ');
    final msg = (_safeGetString(notif, 'message') ?? '').trim();
    if (msg.length > 90) return '${msg.substring(0, 90)}...';
    return msg.isNotEmpty ? msg : 'Nouvelle demande acheteur';
  }

  bool _isAlertNotification(Map<String, dynamic> notif) {
    final data = _notifDataMap(notif);
    final requestType = (data['requestType'] ?? '').toString();
    return _safeGetString(notif, 'type') == 'alerte' ||
        requestType == 'vehicle_search' ||
        requestType == 'piece_search';
  }

  Widget _alertThumbnail(String? url, {bool isPiece = false}) {
    const w = 112.0;
    const h = 63.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              width: w,
              height: h,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _alertThumbnailPlaceholder(isPiece),
            )
          : _alertThumbnailPlaceholder(isPiece),
    );
  }

  Widget _alertThumbnailPlaceholder(bool isPiece) {
    return Container(
      width: 112,
      height: 63,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Icon(
        isPiece ? Icons.build_outlined : Icons.directions_car_outlined,
        color: Colors.grey[500],
        size: 32,
      ),
    );
  }

  Widget _buildUnifiedNotificationListItem({
    required Map<String, dynamic> notif,
    required bool isUnread,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required NotificationProvider provider,
  }) {
    final kind = resolveNotificationVisualKind(notif);
    final imageUrl = notificationThumbUrl(notif) ?? _alertImageUrl(notif);
    final title = _safeGetString(notif, 'title') ?? 'Notification';
    final preview = _isAlertNotification(notif)
        ? _alertPreviewText(notif)
        : notificationPreviewText(notif);
    final dateStr =
        notif['date'] is DateTime ? _formatDate(notif['date'] as DateTime) : '';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
            left: isSelected
                ? const BorderSide(color: Colors.black, width: 3)
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUnread)
              Padding(
                padding: const EdgeInsets.only(top: 22, right: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF065FD4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            buildNotificationLeadingAvatar(
              kind: kind,
              appLogoAsset: 'assets/images/logo_tramoo.png',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            buildNotificationThumbnail(imageUrl, kind),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[700], size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onSelected: (action) => _handleAlertMenuAction(
                action: action,
                notif: notif,
                provider: provider,
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'unread',
                  child: Text(l10n.markAsUnread),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.delete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _safeGetString(dynamic obj, String key) {
    try {
      if (obj is Map && obj.containsKey(key)) {
        final value = obj[key];
        if (value is String) return value;
        if (value != null) return value.toString();
      }
      return null;
    } catch (e) {
      print('Erreur _safeGetString: $e');
      return null;
    }
  }

  Future<void> _openProposalArticle(
    BuildContext context, {
    required String articleId,
    String? typeHint,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sessionExpiredReconnect)),
        );
        return;
      }

      final response = await http.get(
        Uri.parse('${getBaseUrl()}/articles/$articleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger la proposition.')),
        );
        return;
      }

      final article = jsonDecode(response.body);
      final articleType = (article['type'] ?? typeHint ?? '').toString().toLowerCase();

      if (!mounted) return;
      if (articleType == 'piece') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MastervacPage(
              id: article['_id']?.toString(),
              isAcheteur: true,
              title: (article['titre'] ?? '').toString(),
              year: (article['annee'] ?? '').toString(),
              description: (article['description'] ?? '').toString(),
              company: (article['entreprise'] ?? '').toString(),
              location: (article['lieu'] ?? article['localisation'] ?? '').toString(),
              price: (article['prix'] ?? '').toString(),
              fuelType: article['typeMoteur']?.toString(),
              model: article['modele']?.toString(),
              pieceType: (article['pieceType'] ?? article['condition'])?.toString(),
              images: (article['photos'] is List)
                  ? (article['photos'] as List).map((e) => e?.toString()).toList()
                  : const [],
              video: article['video']?.toString(),
              fournisseur: (article['fournisseur'] is Map)
                  ? Map<String, dynamic>.from(article['fournisseur'])
                  : null,
            ),
          ),
        );
      } else {
        final photos = (article['photos'] is List)
            ? (article['photos'] as List)
                .map((e) => e?.toString() ?? '')
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CarsInfo(
              id: article['_id']?.toString(),
              titre: article['titre']?.toString(),
              description: article['description']?.toString(),
              marque: article['marque']?.toString(),
              modele: article['modele']?.toString(),
              annee: article['annee']?.toString(),
              prix: article['prix']?.toString(),
              condition: article['condition']?.toString(),
              boiteVitesse: article['boiteVitesse']?.toString(),
              carburant: article['carburant']?.toString(),
              climatiseur: article['climatiseur']?.toString(),
              distance: article['distance']?.toString(),
              sieges: article['sieges']?.toString(),
              portes: article['portes']?.toString(),
              cylindre: article['cylindre']?.toString(),
              couleur: article['couleur']?.toString(),
              dedouanement: article['dedouanement'] == true,
              lieu: (article['lieu'] ?? article['localisation'])?.toString(),
              images: photos,
              videos: const [],
              video: article['video']?.toString(),
              entreprise: article['entreprise']?.toString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ouverture: $e')),
      );
    }
  }

  void _showNotificationDetail(
    BuildContext context,
    Map<String, dynamic> notification,
    NotificationProvider provider,
    String token,
  ) async {
    try {
      if (!(notification['isRead'] ?? false)) {
        final notificationId = _safeGetString(notification, '_id');
        if (notificationId != null) {
          await provider.markNotificationAsRead(notificationId, token);
          if (mounted) {
            _syncUnreadCountWithHeader(provider);
          }
        }
      }

      showDialog(
        context: context,
        builder: (context) {
          final isVerification =
              _safeGetString(notification, 'type') == 'verification';
          final isPromo = _safeGetString(notification, 'type') == 'promotion';
          final dataMap = (notification['data'] is Map)
              ? Map<String, dynamic>.from(notification['data'])
              : <String, dynamic>{};
          final requestType = (dataMap['requestType'] ?? '').toString();
          final isAlert = _safeGetString(notification, 'type') == 'alerte' ||
              requestType == 'vehicle_search' ||
              requestType == 'piece_search';
          final images = getNotifImages(notification);
          final stampUrl = getStampUrl(notification);
          final signatureUrl = getSignatureUrl(notification);
          final bodyHtml = _safeGetString(notification, 'bodyHtml') ??
              _safeGetString(notification, 'message') ??
              '-';

          Widget detailContent;

          if (isVerification) {
            detailContent = _buildVerificationContent(context, notification,
                provider, token, images, stampUrl, signatureUrl, bodyHtml);
          } else if (isAlert) {
            detailContent = _buildAlertContent(notification, bodyHtml);
          } else if (isPromo) {
            detailContent = _buildPromoContent(notification, images, bodyHtml);
          } else {
            detailContent = _buildStandardContent(notification, bodyHtml);
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: detailContent,
            ),
          );
        },
      );
    } catch (e) {
      print('Erreur _showNotificationDetail: $e');
    }
  }

  Widget _buildVerificationContent(
    BuildContext context,
    Map<String, dynamic> notification,
    NotificationProvider provider,
    String token,
    List<String> images,
    String? stampUrl,
    String? signatureUrl,
    String bodyHtml,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _safeGetString(notification, 'title') ?? '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber[900],
                fontSize: 18,
              ),
            ),
            Text(
              notification['date'] is DateTime
                  ? _formatDate(notification['date'])
                  : "",
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_safeGetString(notification, 'details') != null) ...[
          Text(
            _safeGetString(notification, 'details')!,
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 12),
        ],
        Html(data: bodyHtml),
        if (images.isNotEmpty)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: VerificationDetailPage._safeMapImages(images),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (stampUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Image.network(
                  stampUrl,
                  height: 47,
                  width: 47,
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation(0.9),
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 47,
                      width: 47,
                      color: Colors.grey[300],
                      child: const Icon(Icons.verified, color: Colors.amber),
                    );
                  },
                ),
              ),
            if (signatureUrl != null)
              Image.network(
                signatureUrl,
                height: 34,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 34,
                    width: 100,
                    color: Colors.grey[300],
                    child: const Icon(Icons.edit, color: Colors.blueGrey),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        if ((_safeGetString(notification, 'status') ?? 'pending') == 'pending')
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final notificationId = _safeGetString(notification, '_id');
                  if (notificationId != null) {
                    await provider.handleVerificationAction(
                      notificationId,
                      'approve',
                      token,
                    );
                  }
                  String? articleId = _safeGetString(
                      notification['verificationData'], 'articleId');
                  if (articleId == null) {
                    articleId =
                        _safeGetString(notification['relatedId'], '_id') ??
                            _safeGetString(notification, 'relatedId');
                  }
                  if (articleId != null && articleId.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Cette fonctionnalité n\'est plus disponible'),
                      ),
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Article introuvable pour la vérification')),
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                ),
                child: Text(l10n.validate,
                  style: TextStyle(color: Colors.black),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final notificationId = _safeGetString(notification, '_id');
                  if (notificationId != null) {
                    await provider.handleVerificationAction(
                      notificationId,
                      'reject',
                      token,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[300],
                ),
                child: const Text(
                  "Rejeter",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String? _alertAnneeValue(Map<String, dynamic> dataMap, bool isPiece) {
    final annee = (dataMap['annee'] ?? '').toString().trim();
    if (annee.isNotEmpty) return annee;
    if (!isPiece) {
      final min = (dataMap['anneeMin'] ?? '').toString().trim();
      if (min.isNotEmpty) return min;
    }
    return null;
  }

  String? _alertBudgetValue(Map<String, dynamic> dataMap) {
    final budget = (dataMap['budget'] ?? dataMap['budgetMax'] ?? '')
        .toString()
        .trim();
    return budget.isNotEmpty ? budget : null;
  }

  Widget _buildAlertContent(Map<String, dynamic> notification, String bodyHtml) {
    final dataMap = _notifDataMap(notification);
    final requestType = (dataMap['requestType'] ?? '').toString();
    final isPiece = requestType == 'piece_search';
    final imageUrl = _alertImageUrl(notification);
    final title = _safeGetString(notification, 'title') ?? 'Alerte';
    final preview = _alertPreviewText(notification);
    final description = (dataMap['description'] ?? '').toString();
    final anneeVal = _alertAnneeValue(dataMap, isPiece);
    final budgetVal = _alertBudgetValue(dataMap);
    final dateStr = notification['date'] is DateTime
        ? _formatDate(notification['date'] as DateTime)
        : '';

    final details = <MapEntry<String, String>>[
      if ((dataMap['marque'] ?? '').toString().trim().isNotEmpty)
        MapEntry('Marque', (dataMap['marque'] ?? '').toString().trim()),
      if ((dataMap['modele'] ?? '').toString().trim().isNotEmpty)
        MapEntry('Modèle', (dataMap['modele'] ?? '').toString().trim()),
      if (isPiece && (dataMap['pieceName'] ?? '').toString().trim().isNotEmpty)
        MapEntry('Pièce', (dataMap['pieceName'] ?? '').toString().trim()),
      if (anneeVal != null) MapEntry('Année', anneeVal),
      if (budgetVal != null) MapEntry('Budget', '$budgetVal FCFA'),
      if ((dataMap['urgence'] ?? '').toString().trim().isNotEmpty)
        MapEntry('Urgence', (dataMap['urgence'] ?? '').toString().trim()),
      if (!isPiece && (dataMap['etat'] ?? '').toString().trim().isNotEmpty)
        MapEntry('État', (dataMap['etat'] ?? '').toString().trim()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          GestureDetector(
            onTap: () => _showImageFullscreen(context, imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child: Icon(
                        isPiece
                            ? Icons.build_outlined
                            : Icons.directions_car_outlined,
                        size: 48,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Agrandir',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -0.3,
          ),
        ),
        if (dateStr.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            dateStr,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          preview,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text(
            'Détails de la recherche',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          ...details.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _getIconForField(e.key),
                    size: 18,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          e.value,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              final sourceNotificationId = _safeGetString(notification, '_id');
              final buyerId = _safeGetString(dataMap, 'buyerId') ??
                  _safeGetString(notification['sender'], '_id') ??
                  _safeGetString(notification, 'sender');
              final parentContext = this.context;
              Navigator.of(context, rootNavigator: true).pop();
              final route = MaterialPageRoute(
                builder: (_) => isPiece
                    ? CreateSellPage2(
                        alertNotificationId: sourceNotificationId,
                        alertBuyerId: buyerId,
                        alertRequestType: requestType.isNotEmpty
                            ? requestType
                            : 'piece_search',
                      )
                    : CreateSellPage(
                        alertNotificationId: sourceNotificationId,
                        alertBuyerId: buyerId,
                        alertRequestType: requestType.isNotEmpty
                            ? requestType
                            : 'vehicle_search',
                      ),
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(parentContext).push(route);
              });
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Proposer une offre'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconForField(String field) {
    switch (field) {
      case 'Marque':
        return Icons.business;
      case 'Modèle':
        return Icons.model_training;
      case 'Pièce recherchée':
        return Icons.build;
      case 'Année':
        return Icons.calendar_today;
      case 'Budget':
        return Icons.monetization_on;
      case 'Localisation':
        return Icons.location_on;
      case 'Urgence':
        return Icons.priority_high;
      case 'État':
        return Icons.info_outline;
      default:
        return Icons.fiber_manual_record;
    }
  }

  Widget _buildPromoContent(
      Map<String, dynamic> notification, List<String> images, String bodyHtml) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.yellow[400]!,
            Colors.orange[400]!,
            Colors.yellow[300]!,
          ],
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      padding: const EdgeInsets.all(17),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '🎉 Promotion spéciale',
            style: TextStyle(
              color: Colors.yellow[900],
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _safeGetString(notification, 'title') ?? '',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 21,
              color: Colors.orange[900],
            ),
          ),
          const SizedBox(height: 8),
          Html(
            data: bodyHtml,
            style: {
              '.': Style(
                color: Colors.orange[900],
                fontSize: FontSize(15),
              ),
            },
          ),
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: VerificationDetailPage._safeMapImages(images),
              ),
            ),
          if (_safeGetString(notification, 'ctaLabel') != null &&
              _safeGetString(notification, 'ctaUrl') != null)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                ),
                onPressed: () {
                  // Ouvrir le lien promo
                },
                child: Text(
                  _safeGetString(notification, 'ctaLabel')!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStandardContent(
      Map<String, dynamic> notification, String bodyHtml) {
    final dataMap = (notification['data'] is Map)
        ? Map<String, dynamic>.from(notification['data'])
        : <String, dynamic>{};
    final action = (dataMap['action'] ?? '').toString();
    final targetArticleId =
        (dataMap['targetArticleId'] ?? _safeGetString(notification, 'relatedId') ?? '')
            .toString();
    final targetType = (dataMap['targetType'] ?? '').toString();
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _safeGetString(notification, 'title') ?? '',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Html(
            data: bodyHtml,
            style: {
              '.': Style(color: Colors.blue[900], fontSize: FontSize(15)),
            },
          ),
          if (action == 'view_proposal' && targetArticleId.isNotEmpty) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openProposalArticle(
                  context,
                  articleId: targetArticleId,
                  typeHint: targetType,
                );
              },
              icon: const Icon(Icons.visibility),
              label: const Text('Voir la proposition'),
            ),
          ],
        ],
      ),
    );
  }
}