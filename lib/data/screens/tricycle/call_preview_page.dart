import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

class CallPreviewPage extends StatefulWidget {
  final String name;
  final String phone;

  const CallPreviewPage({
    super.key,
    required this.name,
    required this.phone,
  });

  @override
  State<CallPreviewPage> createState() => _CallPreviewPageState();
}

class _CallPreviewPageState extends State<CallPreviewPage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _calling = false;

  Future<void> _startCall() async {
    setState(() => _calling = true);
    final uri = Uri(scheme: 'tel', path: widget.phone);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => _calling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 30),
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white.withOpacity(0.12),
                child: const Icon(
                  Icons.person,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.phone,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _calling ? 'Appel en cours…' : 'Prêt à appeler',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _calling ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _calling ? null : _startCall,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(l10n.call),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

