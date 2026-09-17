// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
// import 'payement.dart'; // Plus utilisé
import 'package:tranoo_pro/services/user_service.dart'; // Importez UserService pour gérer les rôles
import 'package:tranoo_pro/utils/amount_display.dart';
import 'package:tranoo_pro/widgets/spec_info_card.dart';
import 'package:tranoo_pro/utils/role_redirect.dart';
// import 'package:tranoo_pro/data/screens/paymentscreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io'; // Pour la validation de fichier
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tranoo_pro/data/screens/succes6.dart';
import 'package:confetti/confetti.dart';
import 'dart:developer';
import 'une.dart' as pub_page; // Import pour la page de demande de pub avec préfixe
// import 'verification_payment.dart';
import 'package:tranoo_pro/widgets/video_preview_placeholder.dart';
import 'package:tranoo_pro/utils/whatsapp_helper.dart';
import 'package:tranoo_pro/widgets/cached_media_image.dart';
import 'package:tranoo_pro/utils/article_view_helper.dart';
import 'package:tranoo_pro/utils/auth_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart'; // Pour la sélection d'images
import 'package:flutter/services.dart'; // Pour decodeImageFromList
import 'package:flutter/painting.dart'; // Pour instantiateImageCodec

class MastervacPage extends StatefulWidget {
  final String? id;
  final bool isAcheteur;
  final String title;
  final String year;
  final String description;
  final String company;
  final String? location;
  final String price;
  final String? fuelType;
  final String? model;
  final String? pieceType;
  final String? categorie;
  final String? marque;
  final List<String?> images;
  final String? video;
  final bool fromPub;
  final Map<String, dynamic>? fournisseur; // Ajout des infos fournisseur
  final Map<String, dynamic>? vendeur;
  final bool editMode;
  final String? alertNotificationId;
  final String? alertBuyerId;
  final String? alertRequestType;

  const MastervacPage({
    super.key,
    this.id,
    required this.isAcheteur,
    required this.title,
    required this.year,
    required this.description,
    required this.company,
    this.location, // Rendu optionnel
    required this.price,
    this.fuelType,
    this.model,
    this.pieceType,
    this.categorie,
    this.marque,
    required this.images,
    this.video,
    this.fromPub = false,
    this.fournisseur, // Ajout des infos fournisseur
    this.vendeur,
    this.alertNotificationId,
    this.alertBuyerId,
    this.alertRequestType,
    this.editMode = false,
  });

  @override
  State<MastervacPage> createState() => _MastervacPageState();
}

class _MastervacPageState extends State<MastervacPage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  int _currentImageIndex = 0;
  late PageController _pageController;
  // SUPPRIME la liste statique _images

  TextEditingController detailsController = TextEditingController();
  late ConfettiController _confettiController;
  bool _isOnline = false;
  String? _sellerPhone;
  String? _loadedCategorie;
  String? _loadedMarque;
  String? _loadedLocation;
  String? _loadedCompany;
  
  // Variables pour la gestion des images
  List<File> _selectedImages = [];
  bool _isUploading = false;
  bool _isPublishing = false;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Constantes pour la validation
  static const int _maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int _maxImageWidth = 1920;
  static const int _maxImageHeight = 1080;
  static const List<String> _allowedFormats = ['jpg', 'jpeg', 'png', 'webp'];

  late final TextEditingController _editTitleController;
  late final TextEditingController _editYearController;
  late final TextEditingController _editDescriptionController;
  late final TextEditingController _editCompanyController;
  late final TextEditingController _editLocationController;
  late final TextEditingController _editPriceController;
  late final TextEditingController _editModelController;
  String? _editFuelType;
  String? _editPieceType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    trackArticleView(widget.id);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _pageController = PageController(initialPage: _currentImageIndex);
    if ((widget.id ?? '').trim().isNotEmpty) {
      _isOnline = true;
    }
    _sellerPhone = WhatsappHelper.phoneFromArticleSupplier(
          fournisseur: widget.fournisseur, vendeur: widget.vendeur) ??
        _phoneFromFournisseurWidget();
    _loadArticleDetails();

    _editTitleController = TextEditingController(text: widget.title);
    _editYearController = TextEditingController(text: widget.year);
    _editDescriptionController =
        TextEditingController(text: widget.description);
    _editCompanyController = TextEditingController(text: widget.company);
    _editLocationController = TextEditingController(text: widget.location ?? '');
    _editPriceController = TextEditingController(text: widget.price);
    _editModelController = TextEditingController(text: widget.model ?? '');
    _editFuelType = widget.fuelType?.toString();
    _editPieceType = widget.pieceType?.toString();
  }

  // Fonction pour valider la taille et le format d'une image
  Future<Map<String, dynamic>> _validateImage(File imageFile) async {
    final fileSize = await imageFile.length();
    final fileName = imageFile.path.toLowerCase();
    final extension = fileName.split('.').last;
    
    // Validation du format
    if (!_allowedFormats.contains(extension)) {
      return {
        'isValid': false,
        'error': 'Format non supporté. Formats acceptés: ${_allowedFormats.join(', ')}'
      };
    }
    
    // Validation de la taille
    if (fileSize > _maxImageSize) {
      return {
        'isValid': false,
        'error': 'Image trop volumineuse. Taille maximale: ${_maxImageSize ~/ (1024 * 1024)}MB'
      };
    }
    
    // Validation des dimensions
    try {
      final imageBytes = imageFile.readAsBytesSync();
      final decodedImage = await decodeImageFromList(imageBytes);
      final width = decodedImage.width;
      final height = decodedImage.height;

      if (width > _maxImageWidth || height > _maxImageHeight) {
        return {
          'isValid': false,
          'error':
              'Dimensions trop grandes. Maximum: ${_maxImageWidth}x${_maxImageHeight}px'
        };
      }
    } catch (e) {
      return {
        'isValid': false,
        'error': 'Image corrompue ou invalide'
      };
    }
    
    return {'isValid': true, 'error': null};
  }

  // Fonction pour sélectionner plusieurs images
  Future<void> _pickImages() async {
    if (_isUploading) return;
    
    try {
      final List<XFile>? pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: _maxImageWidth.toDouble(),
        maxHeight: _maxImageHeight.toDouble(),
      );
      
      if (pickedFiles != null) {
        setState(() => _isUploading = true);
        
        List<File> validImages = [];
        List<String> errors = [];
        
        for (final pickedFile in pickedFiles) {
          final file = File(pickedFile.path);
          final validation = await _validateImage(file);
          
          if (validation['isValid']) {
            validImages.add(file);
          } else {
            errors.add('${pickedFile.name}: ${validation['error']}');
          }
        }
        
        if (!mounted) return;
        
        setState(() {
          _selectedImages = validImages;
          _isUploading = false;
        });
        
        if (errors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.imagesNotAllAddedWarning,
                         style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...errors.map((error) => Text('• $error', 
                         style: const TextStyle(fontSize: 12))),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (validImages.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.imagesAddedSuccess(validImages.length)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectionError(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fonction pour sélectionner une seule image
  Future<void> _pickSingleImage() async {
    if (_isUploading) return;
    
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: _maxImageWidth.toDouble(),
        maxHeight: _maxImageHeight.toDouble(),
      );
      
      if (pickedFile != null) {
        setState(() => _isUploading = true);
        
        final file = File(pickedFile.path);
        final validation = await _validateImage(file);
        
        if (!mounted) return;
        
        setState(() => _isUploading = false);
        
        if (validation['isValid']) {
          setState(() {
            _selectedImages.add(file);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.imageAdded(pickedFile.name)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(validation['error']),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectionError(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _phoneFromFournisseurWidget() {
    final f = widget.fournisseur;
    if (f == null) return null;
    final phone = f['telephone']?.toString().trim() ?? '';
    return phone.isEmpty ? null : phone;
  }

  String? _extractSellerPhone(Map<String, dynamic> data) =>
      WhatsappHelper.phoneFromArticle(data) ?? _sellerPhone;

  void _precacheAdjacentImages(int index) {
    if (!mounted || widget.images.isEmpty) return;
    final w = MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context);
    final urls = <String>[];
    for (final delta in [-1, 0, 1]) {
      final i = index + delta;
      if (i < 0 || i >= widget.images.length) continue;
      final url = widget.images[i]?.trim() ?? '';
      if (url.startsWith('http')) urls.add(url);
    }
    precacheMediaImages(
      context,
      urls,
      cloudinaryWidthPx: w.round().clamp(120, 1600),
      maxCount: 3,
    );
  }

  String _digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  void _showSellerContactUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.sellerPhoneUnavailable)),
    );
  }

  Future<void> _openSellerWhatsApp() async {
    await WhatsappHelper.openChat(
      context,
      phone: _sellerPhone,
      unavailableMessage: l10n.sellerPhoneUnavailable,
      cannotOpenMessage: l10n.cannotOpenWhatsApp,
    );
  }

  Future<void> _callSeller() async {
    final phone = _sellerPhone?.trim() ?? '';
    if (phone.isEmpty) {
      _showSellerContactUnavailable();
      return;
    }
    final digits = _digitsOnly(phone);
    if (digits.isEmpty) {
      _showSellerContactUnavailable();
      return;
    }
    final uri = Uri.parse('tel:+$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.cannotMakeCall)),
    );
  }

  bool _articlePublishedStatut(String statut) {
    return statut == 'en_ligne' ||
        statut == 'en_attente' ||
        statut == 'vendu' ||
        statut == 'non_vendu';
  }

  Future<void> _loadArticleDetails() async {
    try {
      final id = widget.id;
      if (id == null || id.isEmpty) return;
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final res = await http.get(
        Uri.parse(getBaseUrl() + '/public/articles/' + id),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer ' + token,
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final statut = (data['statut'] ?? '').toString().toLowerCase();
        final phone = _extractSellerPhone(data) ?? _sellerPhone;
        if (!mounted) return;
        final loc = (data['localisation'] ?? data['lieu'])?.toString().trim();
        final company = data['entreprise']?.toString().trim();
        setState(() {
          _isOnline = _articlePublishedStatut(statut);
          _sellerPhone = phone;
          _loadedCategorie = data['categorie']?.toString();
          _loadedMarque = data['marque']?.toString();
          if (loc != null && loc.isNotEmpty) _loadedLocation = loc;
          if (company != null && company.isNotEmpty) _loadedCompany = company;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _editTitleController.dispose();
    _editYearController.dispose();
    _editDescriptionController.dispose();
    _editCompanyController.dispose();
    _editLocationController.dispose();
    _editPriceController.dispose();
    _editModelController.dispose();
    _confettiController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    if (_saving) return;
    final id = (widget.id ?? '').toString();
    if (id.isEmpty) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return;

      final payload = {
        'type': 'piece',
        'titre': _editTitleController.text.trim(),
        'annee': _editYearController.text.trim(),
        'description': _editDescriptionController.text.trim(),
        'entreprise': _editCompanyController.text.trim(),
        'lieu': _editLocationController.text.trim(),
        'localisation': _editLocationController.text.trim(),
        'prix': _editPriceController.text.trim(),
        'typeMoteur': _editFuelType,
        'modele': _editModelController.text.trim(),
        'pieceType': _editPieceType,
        'photos': widget.images.whereType<String>().toList(),
        'video': widget.video,
        'fournisseur': widget.fournisseur,
      };

      final resp = await http.put(
        Uri.parse(getBaseUrl() + '/articles/' + id),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + token,
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.changesSaved)),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveErrorStatus(resp.statusCode.toString()))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveErrorGeneric(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildEditScaffold() {
    const fuelItems = [
      'Essence',
      'Gazoil',
      'Diesel',
      'Electrique',
      'Hybride',
      'Aucun',
    ];
    const pieceItems = ['Nouveau', 'Occasion'];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(l10n.modifyPart),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _editTitleController,
              decoration: InputDecoration(
                labelText: l10n.titleLabel,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editYearController,
              decoration: InputDecoration(
                labelText: l10n.year,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editModelController,
              decoration: InputDecoration(
                labelText: l10n.model,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _editFuelType,
              items: fuelItems
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _editFuelType = v),
              decoration: InputDecoration(
                labelText: l10n.engineTypeShort,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _editPieceType,
              items: pieceItems
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _editPieceType = v),
              decoration: InputDecoration(
                labelText: l10n.conditionLabel,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editPriceController,
              decoration: InputDecoration(
                labelText: l10n.price,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editCompanyController,
              decoration: InputDecoration(
                labelText: l10n.company,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editLocationController,
              decoration: InputDecoration(
                labelText: l10n.location,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editDescriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.description,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveEdits,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE57373),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Sauvegarder',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.editMode) {
      return _buildEditScaffold();
    }
    // On ne passe plus de booléen, on déduit le rôle ici
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          _buildImageSection(),
          _buildContentSection(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildImageSection() {
    final hasImages = widget.images.isNotEmpty;
    final hasVideo = widget.video != null && widget.video!.isNotEmpty;
    
    return Stack(
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: hasImages
              ? PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) {
              setState(() => _currentImageIndex = i);
              _precacheAdjacentImages(i);
            },
            itemBuilder: (context, index) {
              final String img = widget.images[index] ?? '';
              final Widget child = img.startsWith('http')
                  ? CachedMediaImage(
                      url: img,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      cloudinaryWidthPx:
                          MediaQuery.sizeOf(context).width.toInt(),
                    )
                  : (img.isNotEmpty
                      ? Image.asset(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: Text(l10n.imageNotAvailable),
                            ),
                          ),
                        )
                      : Image.asset(
                          'assets/images/image_not_found.png',
                          fit: BoxFit.cover,
                        ));
              return GestureDetector(
                onTap: () => _openImageViewer(index),
                child: ClipRect(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: child,
                  ),
                ),
              );
            },
                )
              : hasVideo
                  ? VideoPreviewPlaceholder(
                      videoUrl: widget.video,
                      iconSize: 60,
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 80),
                      ),
                    ),
        ),
        // Icônes verticales (droite)
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            children: [
              // WhatsApp
              GestureDetector(
                onTap: _openSellerWhatsApp,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Image.asset(
                    'assets/images/whatsapp_icon.png',
                    width: 22,
                    height: 22,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFF25D366),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Appel téléphonique
              GestureDetector(
                onTap: _callSeller,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: const Icon(
                    Icons.phone,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasImages && widget.images.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: widget.images.length,
                effect: JumpingDotEffect(
                  activeDotColor: Colors.white,
                  dotColor: Colors.white70,
                  dotHeight: 8,
                  dotWidth: 8,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openImageViewer(int startIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (ctx) {
        final controller = PageController(initialPage: startIndex);
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: widget.images.length,
                itemBuilder: (context, index) {
                  final String img = widget.images[index] ?? '';
                  final Widget child = img.startsWith('http')
                      ? CachedMediaImage(
                          url: img,
                          fit: BoxFit.contain,
                          placeholderColor: Colors.black,
                        )
                      : (img.isNotEmpty
                          ? Image.asset(img, fit: BoxFit.contain)
                          : const Icon(
                              Icons.image_not_supported,
                              color: Colors.white,
                              size: 80,
                            ));
                  return Center(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: child,
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: SmoothPageIndicator(
                    controller: controller,
                    count: widget.images.length,
                    effect: WormEffect(
                      activeDotColor: Colors.white,
                      dotColor: Colors.white24,
                      dotHeight: 8,
                      dotWidth: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildDescription(),
          const SizedBox(height: 24),
          _buildSpecifications(),
          const SizedBox(height: 24),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title.isNotEmpty ? widget.title : 'Non renseigné',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              AuthConfig.displayEntreprise(
                widget.company.isNotEmpty ? widget.company : null,
              ),
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.price.isNotEmpty
              ? '${formatFcfaDots(widget.price)} FCFA'
              : 'Non renseigné',
          style: TextStyle(
            fontSize: 20,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
        // Année retirée de l'en-tête
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      (widget.description.isNotEmpty) ? widget.description : 'Non renseigné',
      style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
    );
  }

  String get _effectiveCategorie =>
      (_loadedCategorie ?? widget.categorie ?? '').toLowerCase();

  String get _effectiveMarque =>
      (_loadedMarque ?? widget.marque ?? '').trim();

  String _specValue(String? value) =>
      (value != null && value.trim().isNotEmpty) ? value.trim() : 'Non renseigné';

  Widget _buildSpecifications() {
    const notProvided = 'Non renseigné';
    final locationRaw = concatLocationParts(
      location: _loadedLocation ?? widget.location,
      company: _loadedCompany ?? widget.company,
    );
    final locationValue = locationRaw.isEmpty
        ? notProvided
        : truncateWithEllipsis(locationRaw);

    final List<({String title, String value, IconData icon})> specs;
    switch (_effectiveCategorie) {
      case 'huile_moteur':
        specs = [
          (title: 'Marque', value: _specValue(_effectiveMarque), icon: Icons.business),
          (title: 'Viscosité', value: _specValue(widget.model), icon: Icons.opacity),
          (title: 'Type', value: _specValue(widget.fuelType), icon: Icons.local_gas_station),
          (title: 'Détails', value: _specValue(widget.description), icon: Icons.description),
          (title: 'Localisation', value: locationValue, icon: Icons.location_on),
        ];
        break;
      case 'pneu':
        final dimsMatch =
            RegExp(r'(\d+/\d+\s+R?\d+)').firstMatch(widget.title);
        specs = [
          (title: 'Marque', value: _specValue(_effectiveMarque), icon: Icons.business),
          (title: 'Référence', value: _specValue(widget.model), icon: Icons.tag),
          (
            title: 'Dimensions',
            value: dimsMatch?.group(1) ?? notProvided,
            icon: Icons.straighten,
          ),
          (
            title: 'Type véhicule',
            value: _specValue(widget.fuelType),
            icon: Icons.directions_car,
          ),
          (title: 'Localisation', value: locationValue, icon: Icons.location_on),
        ];
        break;
      default:
        specs = [
          (title: 'Modèle', value: _specValue(widget.model), icon: Icons.settings),
          (
            title: 'État',
            value: _specValue(widget.pieceType),
            icon: Icons.verified,
          ),
          (title: 'Année', value: _specValue(widget.year), icon: Icons.calendar_today),
          (title: 'Localisation', value: locationValue, icon: Icons.location_on),
        ];
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.8,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: specs
          .map(
            (s) => SpecInfoCard(
              title: s.title,
              value: s.value,
              icon: s.icon,
            ),
          )
          .toList(),
    );
  }

  Widget _buildActionButton() {
    final userService = UserService();
    final isVendeur = userService.currentRole == UserRole.vendeur;
    // Buyer cart/checkout is on Tranoo client — Pro keeps product view + seller CTAs only.
    if (widget.fromPub == true || !isVendeur) {
      return const SizedBox.shrink();
    }
    // Vendeur : boutons vendre + pub
    return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOnline ? Colors.grey[300] : Colors.amber,
                foregroundColor: _isOnline ? Colors.grey[600] : Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 64,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: (_isOnline || _isPublishing)
                  ? null
                  : () async {
                      setState(() => _isPublishing = true);
                      log('[DEBUG] Bouton Vendez votre pièce cliqué');
                      final pieceData = {
                        'type': 'piece',
                        'titre': widget.title,
                        'annee': widget.year,
                        'description': widget.description,
                        'entreprise': widget.company,
                        'lieu': widget.location ?? 'Non renseigné',
                        'prix': widget.price,
                        'typeMoteur': widget.fuelType,
                        'modele': widget.model,
                        if ((widget.marque ?? '').isNotEmpty) 'marque': widget.marque,
                        if ((widget.categorie ?? '').isNotEmpty)
                          'categorie': widget.categorie,
                        if (widget.pieceType != null && widget.pieceType!.isNotEmpty)
                          'condition': widget.pieceType,
                        'photos': widget.images.whereType<String>().toList(),
                        'video': widget.video,
                        'fournisseur': widget.fournisseur, // Ajout des infos fournisseur
                        if ((widget.alertBuyerId ?? '').isNotEmpty)
                          'alertContext': {
                            'sourceNotificationId': widget.alertNotificationId,
                            'buyerId': widget.alertBuyerId,
                            'requestType': widget.alertRequestType ?? 'piece_search',
                          },
                      };
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        final token = await user?.getIdToken();
                        final response = await http
                            .post(
                              Uri.parse(getBaseUrl() + '/articles/'),
                              headers: {
                                'Content-Type': 'application/json',
                                if (token != null)
                                  'Authorization': 'Bearer $token',
                              },
                              body: jsonEncode(pieceData),
                            )
                            .timeout(const Duration(seconds: 8));
                        if (response.statusCode == 201 ||
                            response.statusCode == 200) {
                          if (!mounted) return;
                          setState(() => _isOnline = true);
                          _confettiController.play();
                          await Future.delayed(const Duration(seconds: 2));
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SuccesScreen6(),
                            ),
                          );
                        } else {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erreur lors de l\'enregistrement en BDD',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        log(
                          '[DEBUG] Exception lors de l\'appel API (mastervac): $e',
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.networkOrServerError)),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _isPublishing = false);
                        }
                      }
                    },
              child: _isPublishing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Vendez votre pièce',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 64,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                log('[DEBUG] Bouton Faire une pub cliqué');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => pub_page.Une(
                      articleId: null,
                      articleType: 'piece',
                      isStandalone: false,
                      articleTitle: widget.title,
                      articleYear: widget.year,
                      articleLocation: widget.location,
                      articlePrice: widget.price,
                      articleDescription: widget.description,
                      articleCompany: widget.company,
                      articleModel: widget.model,
                      articleFuelType: widget.fuelType,
                      articlePieceType: widget.pieceType,
                      articleImages: widget.images.whereType<String>().toList(),
                      articleVideo: widget.video,
                    ),
                  ),
                );
              },
              child: const Text(
                'Boostez vos ventes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
            gravity: 0.3,
          ),
        ],
      );
  }
}
