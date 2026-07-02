import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tranoo_pro/services/transitaire_access_service.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/utils/api_error_message.dart';
import 'package:tranoo_pro/utils/cloudinary_upload.dart';
import 'package:tranoo_pro/utils/phone_country_config.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';
import 'package:tranoo_pro/widgets/cached_media_image.dart';
import 'package:dio/dio.dart';

class TransitaireVerificationPage extends StatefulWidget {
  final TransitaireAccessState? initialState;
  final VoidCallback? onAccessChanged;

  const TransitaireVerificationPage({
    super.key,
    this.initialState,
    this.onAccessChanged,
  });

  @override
  State<TransitaireVerificationPage> createState() =>
      _TransitaireVerificationPageState();
}

class _TransitaireVerificationPageState
    extends State<TransitaireVerificationPage> with WidgetsBindingObserver {
  final _accessService = TransitaireAccessService();
  final _entrepriseController = TextEditingController();
  final _referenceController = TextEditingController();
  final _picker = ImagePicker();

  TransitaireAccessState? _state;
  bool _loading = true;
  bool _submitting = false;
  String? _rectoUrl;
  String? _versoUrl;
  File? _rectoFile;
  File? _versoFile;
  bool _uploadingRecto = false;
  bool _uploadingVerso = false;

  String? _referenceCountry;
  String? _referenceCountryCode;
  Timer? _statusPollTimer;

  PhoneCountryConfig get _referencePhoneCountry =>
      phoneCountryByName(_referenceCountry);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _referenceCountry = kPhoneCountries.first.name;
    _referenceCountryCode = kPhoneCountries.first.code;
    _state = widget.initialState;
    if (_state != null) {
      _prefillFromState(_state!);
      _loading = false;
      _scheduleStatusPolling();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshStatus();
        _prefillEntrepriseFromProfile();
      });
    } else {
      _refreshStatus(showLoading: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  void _scheduleStatusPolling() {
    _statusPollTimer?.cancel();
    if (_state?.gate == TransitaireGate.verificationPending) {
      _statusPollTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refreshStatus(),
      );
    }
  }

  void _applyAccessState(TransitaireAccessState state) {
    setState(() {
      _state = state;
      _prefillFromState(state);
    });
    _scheduleStatusPolling();
    if (!state.needsVerificationBlock) {
      widget.onAccessChanged?.call();
    }
  }

  @override
  void didUpdateWidget(covariant TransitaireVerificationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialState;
    if (incoming != null && incoming != oldWidget.initialState) {
      _state = incoming;
      _prefillFromState(incoming);
      _loading = false;
      _scheduleStatusPolling();
      if (!incoming.needsVerificationBlock) {
        widget.onAccessChanged?.call();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusPollTimer?.cancel();
    _entrepriseController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _prefillFromState(TransitaireAccessState state) {
    final v = state.verification;
    final entreprise = (v.entrepriseProvenanceNom ?? '').trim();
    if (entreprise.isNotEmpty) {
      _entrepriseController.text = entreprise;
    }
    final parsed = splitCanonicalPhone(v.entrepriseProvenanceReference);
    _referenceCountry = parsed.country.name;
    _referenceCountryCode = parsed.country.code;
    _referenceController.text = parsed.national;
    _rectoUrl = v.carteRectoUrl;
    _versoUrl = v.carteVersoUrl;
  }

  Future<void> _prefillEntrepriseFromProfile() async {
    if (_entrepriseController.text.trim().isNotEmpty) return;
    try {
      final profile = await _accessService.fetchUserProfile();
      final entreprise = (profile['entreprise'] ??
              profile['entrepriseProvenance'] ??
              '')
          .toString()
          .trim();
      if (!mounted || entreprise.isEmpty) return;
      setState(() {
        if (_entrepriseController.text.trim().isEmpty) {
          _entrepriseController.text = entreprise;
        }
      });
    } catch (_) {}
  }

  Future<void> _openReferenceCountryPicker() async {
    if (_isReadOnly) return;
    final controller = TextEditingController();
    var filtered = List<PhoneCountryConfig>.from(kPhoneCountries);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final pickerL10n = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.72,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: pickerL10n.searchCountryOrCode,
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) {
                          final q = v.trim().toLowerCase();
                          setModal(() {
                            filtered = kPhoneCountries.where((c) {
                              return c.name.toLowerCase().contains(q) ||
                                  c.code.toLowerCase().contains(q);
                            }).toList();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final c = filtered[index];
                          return ListTile(
                            leading: Text(
                              c.flag,
                              style: const TextStyle(fontSize: 18),
                            ),
                            title: Text(c.name),
                            trailing: Text(
                              c.code,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              setState(() {
                                _referenceCountry = c.name;
                                _referenceCountryCode = c.code;
                                _referenceController.clear();
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _refreshStatus({bool showLoading = false}) async {
    if (showLoading) setState(() => _loading = true);
    try {
      final state = await _accessService.fetchAccessState();
      if (!mounted) return;
      _applyAccessState(state);
      await _prefillEntrepriseFromProfile();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showTranooToast(
        context,
        message: l10n.transitaireVerificationLoadError,
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isPending =>
      _state?.gate == TransitaireGate.verificationPending;

  bool get _isReadOnly => _isPending;

  bool get _canSubmit =>
      !_isPending &&
      !_submitting &&
      (_state?.gate == TransitaireGate.verificationRequired ||
          _state?.gate == TransitaireGate.verificationRejected);

  bool get _isUploadingCard => _uploadingRecto || _uploadingVerso;

  Future<void> _pickImage(bool isRecto) async {
    if (_isReadOnly) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    setState(() {
      if (isRecto) {
        _rectoFile = file;
        _rectoUrl = null;
        _uploadingRecto = true;
      } else {
        _versoFile = file;
        _versoUrl = null;
        _uploadingVerso = true;
      }
    });
    await _uploadCard(file, isRecto: isRecto);
  }

  Future<void> _uploadCard(File file, {required bool isRecto}) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        throw Exception('upload_failed');
      }
      if (bytes.isEmpty) throw Exception('upload_failed');

      final url = await uploadImageToCloudinary(
        bytes,
        folder: CloudinaryFolders.transitaireVerificationCards,
      );
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        throw Exception('upload_failed');
      }
      setState(() {
        if (isRecto) {
          _rectoUrl = url;
        } else {
          _versoUrl = url;
        }
      });
      showTranooToast(
        context,
        message: isRecto
            ? l10n.transitaireVerificationFrontUploadSuccess
            : l10n.transitaireVerificationBackUploadSuccess,
        isSuccess: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isRecto) {
          _rectoUrl = null;
        } else {
          _versoUrl = null;
        }
      });
      showTranooToast(
        context,
        message: isRecto
            ? l10n.transitaireVerificationFrontUploadFailed
            : l10n.transitaireVerificationBackUploadFailed,
        isError: true,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        if (isRecto) {
          _uploadingRecto = false;
        } else {
          _uploadingVerso = false;
        }
      });
    }
  }

  void _viewCardImage({String? imageUrl, File? localFile, required String label}) {
    if (localFile != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _CardImagePreviewPage(
            label: label,
            localFile: localFile,
          ),
        ),
      );
      return;
    }
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CardImagePreviewPage(
          label: label,
          imageUrl: url,
        ),
      ),
    );
  }

  void _previewCard({
    required String label,
    String? imageUrl,
    File? localFile,
  }) {
    _viewCardImage(imageUrl: imageUrl, localFile: localFile, label: label);
  }

  Future<void> _ensureCardUrlsUploaded() async {
    if ((_rectoUrl == null || _rectoUrl!.isEmpty) &&
        _rectoFile != null &&
        !_uploadingRecto) {
      await _uploadCard(_rectoFile!, isRecto: true);
    }
    if ((_versoUrl == null || _versoUrl!.isEmpty) &&
        _versoFile != null &&
        !_uploadingVerso) {
      await _uploadCard(_versoFile!, isRecto: false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final l10n = AppLocalizations.of(context)!;

    final entreprise = _entrepriseController.text.trim();
    final national = _referenceController.text.trim();
    if (entreprise.isEmpty || national.isEmpty) {
      showTranooToast(
        context,
        message: l10n.transitaireVerificationCompanyRequired,
        isError: true,
      );
      return;
    }
    if (!_referencePhoneCountry.isValidNationalNumber(national)) {
      showTranooToast(
        context,
        message: l10n.transitaireVerificationReferencePhoneInvalid,
        isError: true,
      );
      return;
    }
    final reference = canonicalPhoneDigitsFromInput(
      _referenceCountryCode ?? '+229',
      national,
    );
    if (reference.length < 8 || reference.length > 15) {
      showTranooToast(
        context,
        message: l10n.transitaireVerificationReferencePhoneInvalid,
        isError: true,
      );
      return;
    }
    if ((_rectoFile == null && (_rectoUrl == null || _rectoUrl!.isEmpty)) ||
        (_versoFile == null && (_versoUrl == null || _versoUrl!.isEmpty))) {
      showTranooToast(
        context,
        message: l10n.transitaireVerificationCardsRequired,
        isError: true,
      );
      return;
    }
    if (_isUploadingCard) {
      showTranooToast(
        context,
        message: l10n.transitaireVerificationUploadInProgress,
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _ensureCardUrlsUploaded();
      if (_isUploadingCard) {
        showTranooToast(
          context,
          message: l10n.transitaireVerificationUploadInProgress,
          isError: true,
        );
        return;
      }

      final recto = _rectoUrl?.trim();
      final verso = _versoUrl?.trim();
      if (recto == null || verso == null || recto.isEmpty || verso.isEmpty) {
        showTranooToast(
          context,
          message: l10n.transitaireVerificationUploadFailed,
          isError: true,
        );
        return;
      }

      final newState = await _accessService.submitVerification(
        carteRectoUrl: recto,
        carteVersoUrl: verso,
        entrepriseProvenanceNom: entreprise,
        entrepriseProvenanceReference: reference,
      );
      if (!mounted) return;
      _applyAccessState(newState);
      showTranooToast(
        context,
        message: l10n.transitaireVerificationSubmitSuccess,
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('[VERIF] submit error: $e');
      var message = l10n.transitaireVerificationSubmitFailed;
      if (e is DioException) {
        message = ApiErrorMessage.fromDio(l10n, e);
        debugPrint('[VERIF] response: ${e.response?.data}');
      }
      showTranooToast(context, message: message, isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gate = _state?.gate ?? TransitaireGate.verificationRequired;
    final rejection = _state?.verification.rejectionMotif;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: kTransitaireNavy,
        foregroundColor: kTransitaireAmber,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        titleSpacing: 0,
        toolbarHeight: 76,
        title: Text(
          l10n.transitaireVerificationTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: kTransitaireAmber,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: kTransitaireAmber,
          onRefresh: _refreshStatus,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(color: kTransitaireAmber),
                    ),
                  ),
                if (!_loading) ...[
                  _StatusBanner(
                  gate: gate,
                  verificationStatut: _state?.verification.statut,
                  rejectionMotif: rejection,
                ),
                  if (_isReadOnly) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.transitaireVerificationPendingReadOnlyHint,
                      style: TextStyle(
                        color: kTransitaireNavy.withOpacity(0.75),
                        fontSize: 13,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
            Text(
              l10n.transitaireVerificationLegacyHint,
              style: TextStyle(
                color: kTransitaireNavy.withOpacity(0.75),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.transitaireVerificationCardSectionTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: kTransitaireNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.transitaireVerificationCardSectionHint,
              style: const TextStyle(color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DocUploadSlot(
                    label: l10n.transitaireVerificationCardFront,
                    imageUrl: _rectoUrl,
                    localFile: _rectoFile,
                    isUploading: _uploadingRecto,
                    readOnly: _isReadOnly,
                    onPick: () => _pickImage(true),
                    onPreview: () => _previewCard(
                      label: l10n.transitaireVerificationCardFront,
                      imageUrl: _rectoUrl,
                      localFile: _rectoFile,
                    ),
                    onEdit: () => _pickImage(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DocUploadSlot(
                    label: l10n.transitaireVerificationCardBack,
                    imageUrl: _versoUrl,
                    localFile: _versoFile,
                    isUploading: _uploadingVerso,
                    readOnly: _isReadOnly,
                    onPick: () => _pickImage(false),
                    onPreview: () => _previewCard(
                      label: l10n.transitaireVerificationCardBack,
                      imageUrl: _versoUrl,
                      localFile: _versoFile,
                    ),
                    onEdit: () => _pickImage(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.transitaireVerificationCompanySectionTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: kTransitaireNavy,
              ),
            ),
            const SizedBox(height: 12),
            _TranooTextField(
              controller: _entrepriseController,
              hint: l10n.transitaireVerificationCompanyNameHint,
              readOnly: _isReadOnly,
              icon: Icons.business_outlined,
            ),
            const SizedBox(height: 12),
            _ReferencePhoneField(
              controller: _referenceController,
              readOnly: _isReadOnly,
              countryCode: _referenceCountryCode ?? '+229',
              countryFlag: _referencePhoneCountry.flag,
              digitHint: _referencePhoneCountry.digitHint,
              nationalHint: l10n.forgotPasswordNationalHint(
                _referenceCountryCode ?? '+229',
              ),
              onCountryTap: _openReferenceCountryPicker,
            ),
            const SizedBox(height: 28),
            if (_canSubmit)
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTransitaireAmber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          gate == TransitaireGate.verificationRejected
                              ? l10n.transitaireVerificationResubmitButton
                              : l10n.transitaireVerificationSubmitButton,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _CardImagePreviewPage extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final File? localFile;

  const _CardImagePreviewPage({
    required this.label,
    this.imageUrl,
    this.localFile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(label),
      ),
      body: Center(
        child: InteractiveViewer(
          child: localFile != null
              ? Image.file(localFile!, fit: BoxFit.contain)
              : CachedMediaImage(
                  url: imageUrl!,
                  fit: BoxFit.contain,
                  cloudinaryWidthPx: 1200,
                  errorWidget: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final TransitaireGate gate;
  final String? verificationStatut;
  final String? rejectionMotif;

  const _StatusBanner({
    required this.gate,
    this.verificationStatut,
    this.rejectionMotif,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    late final Color bg;
    late final Color border;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    switch (gate) {
      case TransitaireGate.verificationPending:
        bg = const Color(0xFFFFF8E1);
        border = kTransitaireAmber;
        icon = Icons.schedule_rounded;
        if (verificationStatut == 'pending_resubmit') {
          title = l10n.transitaireVerificationBannerResubmitPendingTitle;
          subtitle = l10n.transitaireVerificationBannerResubmitPendingSubtitle;
        } else {
          title = l10n.transitaireVerificationBannerPendingTitle;
          subtitle = l10n.transitaireVerificationBannerPendingSubtitle;
        }
        break;
      case TransitaireGate.verificationRejected:
        bg = const Color(0xFFFFEBEE);
        border = const Color(0xFFB3261E);
        icon = Icons.info_outline_rounded;
        title = l10n.transitaireVerificationBannerRejectedTitle;
        subtitle = rejectionMotif?.trim().isNotEmpty == true
            ? l10n.transitaireVerificationBannerRejectedWithMotif(
                rejectionMotif!.trim(),
              )
            : l10n.transitaireVerificationBannerRejectedSubtitle;
        break;
      case TransitaireGate.subscriptionRequired:
      case TransitaireGate.subscriptionExpired:
        bg = const Color(0xFFE8F5E9);
        border = const Color(0xFF2E7D32);
        icon = Icons.verified_rounded;
        title = l10n.transitaireVerificationBannerApprovedTitle;
        subtitle = l10n.transitaireVerificationBannerApprovedSubtitle;
        break;
      default:
        bg = const Color(0xFFE8EEF8);
        border = kTransitaireNavy;
        icon = Icons.verified_user_outlined;
        title = l10n.transitaireVerificationBannerRequiredTitle;
        subtitle = l10n.transitaireVerificationBannerRequiredSubtitle;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: border, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: border,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black87,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocUploadSlot extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final File? localFile;
  final bool isUploading;
  final bool readOnly;
  final VoidCallback onPick;
  final VoidCallback onPreview;
  final VoidCallback onEdit;

  const _DocUploadSlot({
    required this.label,
    required this.imageUrl,
    required this.localFile,
    required this.isUploading,
    required this.readOnly,
    required this.onPick,
    required this.onPreview,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        localFile != null || (imageUrl != null && imageUrl!.isNotEmpty);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: !hasImage && !readOnly ? onPick : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 152,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasImage
                  ? kTransitaireAmber.withOpacity(0.6)
                  : Colors.grey.shade300,
            ),
          ),
          child: isUploading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: kTransitaireAmber,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: kTransitaireNavy,
                      ),
                    ),
                  ],
                )
              : hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: onPreview,
                        behavior: HitTestBehavior.opaque,
                        child: localFile != null
                            ? Image.file(localFile!, fit: BoxFit.cover)
                            : CachedMediaImage(
                                url: imageUrl!,
                                fit: BoxFit.cover,
                                cloudinaryWidthPx: 400,
                                errorWidget: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      color: readOnly
                                          ? Colors.grey
                                          : kTransitaireNavy,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: readOnly
                                            ? Colors.grey
                                            : kTransitaireNavy,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Material(
                          color: kTransitaireNavy,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            onTap: readOnly ? onPreview : onEdit,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                readOnly ? Icons.zoom_in : Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!readOnly)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Modifier',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: readOnly ? Colors.grey.shade400 : kTransitaireNavy,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: readOnly ? Colors.grey.shade400 : kTransitaireNavy,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ReferencePhoneField extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final String countryCode;
  final String countryFlag;
  final String digitHint;
  final String nationalHint;
  final VoidCallback onCountryTap;

  const _ReferencePhoneField({
    required this.controller,
    required this.readOnly,
    required this.countryCode,
    required this.countryFlag,
    required this.digitHint,
    required this.nationalHint,
    required this.onCountryTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.transitaireVerificationCompanyRefHint,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: kTransitaireNavy,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: readOnly ? null : onCountryTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(countryFlag, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        countryCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: readOnly ? Colors.grey : kTransitaireNavy,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: readOnly,
                enableInteractiveSelection: !readOnly,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: digitHint,
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: kTransitaireNavy,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: kTransitaireAmber,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          nationalHint,
          style: TextStyle(
            color: kTransitaireNavy.withOpacity(0.7),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _TranooTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool readOnly;
  final IconData icon;
  final TextInputType? keyboardType;

  const _TranooTextField({
    required this.controller,
    required this.hint,
    this.readOnly = false,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      enableInteractiveSelection: !readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: kTransitaireNavy),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kTransitaireAmber, width: 1.5),
        ),
      ),
    );
  }
}
