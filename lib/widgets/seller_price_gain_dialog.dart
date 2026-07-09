import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tranoo_pro/utils/amount_display.dart';

/// Jaune officiel Tranoo (boutons, filtres, accents).
const Color kTranooYellow = Color(0xFFF8BF13);

String _formatNetFcfa(double? net) {
  if (net == null || !net.isFinite) return '— FCFA';
  final decimals = net == net.roundToDouble() ? 0 : 2;
  return '${formatFcfaDots(net.toStringAsFixed(decimals))} FCFA';
}

Future<void> showSellerPriceGainDialog({
  required BuildContext context,
  required TextEditingController controller,
  required int tranooGainFcfa,
  String vehicleLabel = 'véhicule',
}) async {
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _SellerPriceGainDialog(
        initialText: controller.text,
        tranooGainFcfa: tranooGainFcfa,
        vehicleLabel: vehicleLabel,
      );
    },
  );

  if (result != null) {
    controller.text = result;
  }
}

class _SellerPriceGainDialog extends StatefulWidget {
  final String initialText;
  final int tranooGainFcfa;
  final String vehicleLabel;

  const _SellerPriceGainDialog({
    required this.initialText,
    required this.tranooGainFcfa,
    required this.vehicleLabel,
  });

  @override
  State<_SellerPriceGainDialog> createState() => _SellerPriceGainDialogState();
}

class _SellerPriceGainDialogState extends State<_SellerPriceGainDialog> {
  late final TextEditingController _draft;

  @override
  void initState() {
    super.initState();
    _draft = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _close([String? value]) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(value);
  }

  void _validate() {
    final parsed = tryParseFlexibleAmount(_draft.text);
    final net = parsed == null ? null : parsed.toDouble() - widget.tranooGainFcfa;
    if (parsed == null || (net != null && net < 0)) return;
    _close(_draft.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final parsed = tryParseFlexibleAmount(_draft.text);
    final net = parsed == null ? null : parsed.toDouble() - widget.tranooGainFcfa;
    final canValidate = parsed != null && (net == null || net >= 0);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kTranooYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Prix de vente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Indiquez le prix de votre ${widget.vehicleLabel}. Tranoo prélève '
              '${formatFcfaDots(widget.tranooGainFcfa.toString())} FCFA sur chaque vente.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Votre prix (FCFA)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _draft,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                ...decimalOptionalInputFormatters,
                LengthLimitingTextInputFormatter(14),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Ex : 2.500.000',
                filled: true,
                fillColor: const Color(0xFFF2F2F2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kTranooYellow, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: kTranooYellow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kTranooYellow.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ce qui vous reste',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatNetFcfa(net),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: net != null && net < 0
                          ? Colors.red.shade700
                          : Colors.black87,
                    ),
                  ),
                  if (net != null && net < 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Le prix doit couvrir au moins le gain Tranoo.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _close(),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kTranooYellow,
                      foregroundColor: const Color(0xFF1A1A1A),
                      disabledBackgroundColor:
                          kTranooYellow.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.black38,
                    ),
                    onPressed: canValidate ? _validate : null,
                    child: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
