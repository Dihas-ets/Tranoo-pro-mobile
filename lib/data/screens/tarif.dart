import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

class Tarif extends StatefulWidget {
  const Tarif({super.key});

  @override
  State<Tarif> createState() => _TarifState();
}

class _TarifState extends State<Tarif> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool loading = false;
  String? errorMsg;
  final UserService _userService = UserService();
  List<dynamic> _transitaires = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });
    try {
      if (_userService.isChauffeur || _userService.isLivreur) {
        await _loadTransitaires();
      }
    } catch (e) {
      errorMsg = 'Impossible de charger les données';
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _loadTransitaires() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    final dio = Dio(
      BaseOptions(
        baseUrl: UserService().dio.options.baseUrl,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    final resp = await dio.get(
      '/users',
      queryParameters: {'role': 'transitaire'},
    );
    _transitaires = resp.data is List ? resp.data : (resp.data['users'] ?? []);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   centerTitle: true,
      //   title: Row(
      //     mainAxisSize: MainAxisSize.min,
      //     // children: const [
      //     //   Icon(Icons.workspace_premium, color: Colors.black),
      //     //   SizedBox(width: 8),
      //     //   Text('Abonnement'),
      //     // ],
      //   ),
      //   backgroundColor: const Color(0xFFF8BF13),
      //   foregroundColor: Colors.black,
      //   elevation: 0,
      // ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (_userService.isChauffeur || _userService.isLivreur)
              ? _buildChauffeurView()
              : Center(child: Text(l10n.pageNotAvailableForRole)),
    );
  }

  Widget _buildChauffeurView() {
    if (errorMsg != null) return Center(child: Text(errorMsg!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFCC00), Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Transitaires recommandés',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _transitaires.length,
            itemBuilder: (context, index) {
              final u = _transitaires[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF8BF13),
                    child: Text(
                      ((u['entreprise'] ?? u['prenoms'] ?? 'T') as String)
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text((u['entreprise'] ?? '-') as String),
                  subtitle: Text((u['email'] ?? '-') as String),
                  trailing: const Icon(Icons.verified, color: Colors.green),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
