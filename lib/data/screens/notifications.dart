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
                    child: const Text('Valider',
                        style: TextStyle(color: Colors.black)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _postVerificationAction(context, 'reject');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Demande rejetée')),
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
  const Notifications({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationProvider(),
      child: const NotificationsBody(),
    );
  }
}

class NotificationsBody extends StatefulWidget {
  const NotificationsBody({super.key});

  @override
  State<NotificationsBody> createState() => _NotificationsBodyState();
}

class _NotificationsBodyState extends State<NotificationsBody> {
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
          });
        }
      });
    } else {
      print(
          'Aucun utilisateur connecté. Impossible de charger les notifications.');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    title: const Text('Supprimer'),
                    content: Text(
                      'Supprimer ${_selectedNotificationIds.length} notification(s) ?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE57373),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Supprimer'),
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
              ? const Center(
                  child: Text(
                    'Aucune notification',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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

          return GestureDetector(
            onTap: () async {
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
            },
            onLongPress: () {
              if (notifId.isEmpty) return;
              _toggleSelection(notifId);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: isVerification
                    ? Colors.amber[50]
                    : (isAlert ? const Color(0xFFFFF1F1) : Colors.blue[50]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF111827)
                      : (isAlert
                          ? const Color(0xFFE57373).withOpacity(0.35)
                          : Colors.transparent),
                  width: isSelected ? 1.2 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                leading: isProposalNotification && proposalThumb.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          proposalThumb,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              CircleAvatar(
                            backgroundColor:
                                isVerification
                                    ? Colors.amber
                                    : (isAlert
                                        ? const Color(0xFFE57373)
                                        : Colors.blue),
                            child: Icon(
                              isVerification
                                  ? Icons.verified
                                  : Icons.notifications,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: isVerification
                            ? Colors.amber
                            : (isAlert ? const Color(0xFFE57373) : Colors.blue),
                        child: Icon(
                            isVerification ? Icons.verified : Icons.notifications,
                            color: Colors.white),
                      ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _safeGetString(notif, 'title') ?? '-',
                        style: TextStyle(
                          fontWeight:
                              isUnread ? FontWeight.bold : FontWeight.normal,
                          color: isVerification
                              ? Colors.amber[800]
                              : (isAlert
                                  ? const Color(0xFFB91C1C)
                                  : Colors.blue[800]),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Nouveau',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isProposalNotification && proposalTitle.isNotEmpty)
                      Text(
                        proposalTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    Text(
                      _safeGetString(notif, 'message') != null
                          ? (_safeGetString(notif, 'message')!.length > 52
                              ? _safeGetString(notif, 'message')!.substring(0, 52) +
                                  '...'
                              : _safeGetString(notif, 'message')!)
                          : '-',
                      maxLines: 2,
                    ),
                  ],
                ),
                trailing: Text(
                  notif['date'] is DateTime ? _formatDate(notif['date']) : '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Erreur _buildNotificationsList: $e');
      return const Center(
        child: Text('Erreur lors du chargement des notifications'),
      );
    }
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return 'Il y a ${diff.inDays} jours';
    if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inMinutes} minutes';
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
          const SnackBar(content: Text('Session expirée. Reconnectez-vous.')),
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
                child: const Text(
                  "Valider",
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

  // ========== NOUVEAU DESIGN DES ALERTES ==========
  Widget _buildAlertContent(Map<String, dynamic> notification, String bodyHtml) {
    final dataMap = (notification['data'] is Map)
        ? Map<String, dynamic>.from(notification['data'])
        : <String, dynamic>{};
    final requestType = (dataMap['requestType'] ?? '').toString();
    final fallbackMessage = (_safeGetString(notification, 'message') ?? '').toLowerCase();
    final isPiece = requestType == 'piece_search' ||
        fallbackMessage.contains('pièce') ||
        fallbackMessage.contains('piece');
    
    // Construction des caractéristiques
    final List<MapEntry<String, String>> characteristics = [];
    
    if ((dataMap['marque'] ?? '').toString().isNotEmpty) {
      characteristics.add(MapEntry('Marque', dataMap['marque'].toString()));
    }
    if ((dataMap['modele'] ?? '').toString().isNotEmpty) {
      characteristics.add(MapEntry('Modèle', dataMap['modele'].toString()));
    }
    if ((dataMap['pieceName'] ?? '').toString().isNotEmpty && isPiece) {
      characteristics.add(MapEntry('Pièce recherchée', dataMap['pieceName'].toString()));
    }
    if ((dataMap['annee'] ?? '').toString().isNotEmpty && isPiece) {
      characteristics.add(MapEntry('Année', dataMap['annee'].toString()));
    }
    if ((dataMap['anneeMin'] ?? '').toString().isNotEmpty && !isPiece) {
      characteristics.add(MapEntry('Année min', dataMap['anneeMin'].toString()));
    }
    if ((dataMap['anneeMax'] ?? '').toString().isNotEmpty && !isPiece) {
      characteristics.add(MapEntry('Année max', dataMap['anneeMax'].toString()));
    }
    if ((dataMap['budgetMax'] ?? '').toString().isNotEmpty) {
      characteristics.add(MapEntry('Budget max', '${dataMap['budgetMax']} FCFA'));
    }
    if ((dataMap['quantity'] ?? '').toString().isNotEmpty) {
      characteristics.add(
        MapEntry('Quantité recherchée', dataMap['quantity'].toString()),
      );
    }
    if ((dataMap['localisation'] ?? '').toString().isNotEmpty) {
      characteristics.add(MapEntry('Localisation', dataMap['localisation'].toString()));
    }
    if ((dataMap['urgence'] ?? '').toString().isNotEmpty) {
      characteristics.add(MapEntry('Urgence', dataMap['urgence'].toString()));
    }
    if ((dataMap['etat'] ?? '').toString().isNotEmpty && !isPiece) {
      characteristics.add(MapEntry('État', dataMap['etat'].toString()));
    }

    final description = (dataMap['description'] ?? '').toString();

    const primaryAmber = Color(0xFFE57373);
    const borderColor = Color(0xFFE5E7EB);
    const bgColor = Color(0xFFF9FAFB);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF4B5563);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryAmber.withOpacity(0.35)),
                ),
                child: Icon(
                  isPiece ? Icons.build_circle : Icons.directions_car,
                  color: primaryAmber,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPiece ? "Alerte piece detachee" : "Alerte vehicule",
                      style: const TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Nouvelle demande d'achat",
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              isPiece
                  ? "Un acheteur recherche activement une pièce détachée. Voici les détails de sa demande :"
                  : "Un acheteur souhaite acquérir un véhicule. Consultez les critères de sa recherche :",
              style: const TextStyle(
                color: textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: primaryAmber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Détails de la demande",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (characteristics.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: characteristics.map((char) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: borderColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getIconForField(char.key),
                          size: 14,
                          color: primaryAmber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${char.key}: ",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                        Text(
                          char.value,
                          style: const TextStyle(
                            fontSize: 12,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Information complementaire",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Bouton "Proposer une offre"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
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
                          alertRequestType: requestType.isNotEmpty ? requestType : 'piece_search',
                        )
                      : CreateSellPage(
                          alertNotificationId: sourceNotificationId,
                          alertBuyerId: buyerId,
                          alertRequestType:
                              requestType.isNotEmpty ? requestType : 'vehicle_search',
                        ),
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.of(parentContext).push(route);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57373),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Proposer une offre',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Message de contact
          Center(
            child: Text(
              "Envoyez votre proposition d'offre à l'acheteur ",
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFFB91C1C).withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
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
      case 'Année min':
      case 'Année max':
        return Icons.calendar_today;
      case 'Budget max':
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