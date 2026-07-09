import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:tranoo_pro/utils/feexpay_callback_state.dart';

/// Doc FeexPay V2 (front) : paramètre **`ref`** sur l’URL de callback.
const List<String> _feexPayTransactionIdKeys = [
  'ref',
  'reference',
  'id_transaction',
  'transaction_id',
  'transactionId',
  'short_code',
  'shortCode',
  'payment_reference',
  'custom_id',
  'order_id',
];

String? _firstNonEmptyFromMap(Map<String, String> map, Iterable<String> keys) {
  for (final k in keys) {
    final v = map[k]?.trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

String? _firstNonEmptyFromArgsMap(dynamic args, Iterable<String> keys) {
  if (args is! Map) return null;
  for (final k in keys) {
    final v = args[k]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

/// FeexPay / feexpay_flutter peut passer la `reference` UUID en **String** brute dans `RouteSettings.arguments`.
final RegExp _feexFullUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
final RegExp _feexAgRef = RegExp(r'\bAG_[A-Za-z0-9_]+\b');

String? _feexIdFromRawArguments(dynamic args) {
  if (args == null) return null;
  final fromMap = _firstNonEmptyFromArgsMap(args, _feexPayTransactionIdKeys);
  if (fromMap != null) return fromMap;
  if (args is String) {
    final t = args.trim();
    if (t.isEmpty) return null;
    if (_feexFullUuid.hasMatch(t)) return t;
    final trn =
        RegExp(r'\bTRN-[A-Z0-9-]+\b', caseSensitive: false).firstMatch(t);
    if (trn != null) return trn.group(0);
    final ag = _feexAgRef.firstMatch(t);
    if (ag != null) return ag.group(0);
    if (t.startsWith('{') && t.endsWith('}')) {
      try {
        final m = jsonDecode(t);
        if (m is Map)
          return _firstNonEmptyFromArgsMap(m, _feexPayTransactionIdKeys);
      } catch (_) {}
    }
  }
  return null;
}

Map<String, String> _feexQueryParamsFromRouteName(String? name) {
  if (name == null || name.isEmpty) return {};
  final qi = name.indexOf('?');
  if (qi < 0 || qi >= name.length - 1) return {};
  return Uri.splitQueryString(name.substring(qi + 1));
}

void _logFeexPayRedirectDebug(RouteSettings? settings, String source) {
  void line(String msg) {
    print('DEBUG_FEEEXPAY[$source] $msg');
    developer.log(msg, name: 'DEBUG_FEEEXPAY');
  }

  if (settings == null) {
    line('settings=null');
    return;
  }

  final name = settings.name;
  line('Route name brut: $name');
  line(
    'arguments type=${settings.arguments?.runtimeType} valeur=${settings.arguments}',
  );

  final qpSplit = _feexQueryParamsFromRouteName(name);
  if (qpSplit.isNotEmpty) {
    line('Query (Uri.splitQueryString): $qpSplit');
  } else {
    line('Aucune query string après ? sur le route name');
  }

  if (name != null && name.isNotEmpty) {
    try {
      final uri = name.contains('://')
          ? Uri.parse(name)
          : Uri.parse('https://feexpay.redirect.debug$name');
      line('Uri.parse queryParameters: ${uri.queryParameters}');
    } catch (e) {
      line('Uri.parse échoué: $e');
    }
  }

  final fromArgs = _feexIdFromRawArguments(settings.arguments);
  final fromQuery = _firstNonEmptyFromMap(qpSplit, _feexPayTransactionIdKeys);
  line(
    'ID déduit (priorité args puis query): ${fromArgs ?? fromQuery ?? "(aucun)"}',
  );
}

String? feexIdFromRouteSettings(RouteSettings? settings) {
  if (settings == null) return null;
  final fromArgs = _feexIdFromRawArguments(settings.arguments);
  if (fromArgs != null) return fromArgs;

  final name = settings.name;
  final qp = _feexQueryParamsFromRouteName(name);
  final fromQuery = _firstNonEmptyFromMap(qp, _feexPayTransactionIdKeys);
  if (fromQuery != null) return fromQuery;

  if (name != null && name.isNotEmpty) {
    try {
      final uri = name.contains('://')
          ? Uri.parse(name)
          : Uri.parse('https://feexpay.redirect.debug$name');
      final fromUri = _firstNonEmptyFromMap(
        uri.queryParameters,
        _feexPayTransactionIdKeys,
      );
      if (fromUri != null) return fromUri;
    } catch (_) {}
  }
  return null;
}

/// Ferme la route callback puis [ChoicePage] pour que [openFeexPayV2Payment] reprenne.
void _popFeexPayCallbackChain(
  BuildContext context,
  Map<String, dynamic> payload,
) {
  final nav = Navigator.of(context, rootNavigator: true);
  nav.pop(payload);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (nav.canPop()) {
      nav.pop(payload);
    }
  });
}

/// Route enregistrée pour les `redirecturl` / `errorredirecturl` de FeexPay (ChoicePage).
class FeexPayChoiceCallbackPage extends StatefulWidget {
  final bool success;

  const FeexPayChoiceCallbackPage({super.key, required this.success});

  @override
  State<FeexPayChoiceCallbackPage> createState() =>
      _FeexPayChoiceCallbackPageState();
}

class _FeexPayChoiceCallbackPageState extends State<FeexPayChoiceCallbackPage> {
  bool _handled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handled) return;
    _handled = true;
    final tag = ModalRoute.of(context)?.settings.name ?? 'feexpay_callback';
    developer.log(
      '[FEEPAY_CALLBACK][$tag] success=${widget.success} args=${ModalRoute.of(context)?.settings.arguments}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = ModalRoute.of(context)?.settings;
      _logFeexPayRedirectDebug(settings, tag);
      final feexId = feexIdFromRouteSettings(settings);
      FeexPayCallbackState.report(
        success: widget.success,
        args: feexId ?? settings?.arguments?.toString(),
        transactionId: feexId,
      );
      final payload = <String, dynamic>{
        'success': widget.success,
        'successHint': widget.success,
        'routeName': settings?.name,
        'callbackArgs': settings?.arguments?.toString(),
        if (feexId != null && feexId.isNotEmpty) 'id_transaction': feexId,
        if (feexId != null && feexId.isNotEmpty) 'ref': feexId,
        if (feexId != null && feexId.isNotEmpty) 'reference': feexId,
      };
      developer.log('[FEEPAY_CALLBACK] pop payload=$payload feexId=$feexId');
      _popFeexPayCallbackChain(context, payload);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: widget.success ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}
