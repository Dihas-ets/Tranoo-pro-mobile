import 'dart:io';
import 'package:tranoo_pro/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

import 'mastervacpage.dart';
import '../../utils/cloudinary_upload.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as local_auth;
import 'package:tranoo_pro/services/user_service.dart';
import 'dart:developer';
import 'map_picker_screen.dart';
import '../../widgets/location_permission_dialog.dart';
import 'movie.dart';
import 'package:tranoo_pro/utils/amount_display.dart';
import 'package:tranoo_pro/services/seller_profile_locations.dart';
import 'package:tranoo_pro/widgets/country_location_field.dart';
import 'package:tranoo_pro/utils/location_geocode_helper.dart';
import 'package:tranoo_pro/widgets/cached_media_image.dart';

enum PieceSellCategory { pieceDetachee, pneu, huileMoteur }

class CreateSellPage2 extends StatefulWidget {
  final String? alertNotificationId;
  final String? alertBuyerId;
  final String? alertRequestType;
  final bool editMode;
  final String? editArticleId;
  final Map<String, dynamic>? initialData;

  const CreateSellPage2({
    super.key,
    this.alertNotificationId,
    this.alertBuyerId,
    this.alertRequestType,
    this.editMode = false,
    this.editArticleId,
    this.initialData,
  });

  @override
  CreateSellPage2State createState() => CreateSellPage2State();
}

class CreateSellPage2State extends State<CreateSellPage2> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const int _maxMediaSlots = 12;

  PieceSellCategory _sellCategory = PieceSellCategory.pieceDetachee;

  // Pièce détachée
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _anneeController = TextEditingController();
  final TextEditingController _marqueModeleController = TextEditingController();
  String? _selectedPieceCondition;

  // Huile moteur
  final TextEditingController _oilCommercialNameController =
      TextEditingController();
  final TextEditingController _oilDescriptionController =
      TextEditingController();
  final TextEditingController _oilBrandController = TextEditingController();
  String? _selectedOilViscosity;
  String? _selectedOilType;
  String? _selectedOilVolume;
  final TextEditingController _oilViscosityOtherController =
      TextEditingController();
  final TextEditingController _oilVolumeOtherController =
      TextEditingController();

  // Pneu
  final TextEditingController _tireBrandController = TextEditingController();
  final TextEditingController _tireModelController = TextEditingController();
  final TextEditingController _tireWidthController = TextEditingController();
  final TextEditingController _tireHeightController = TextEditingController();
  final TextEditingController _tireDiameterController = TextEditingController();
  String? _selectedTireVehicleType;
  final TextEditingController _tireVehicleTypeOtherController =
      TextEditingController();

  final TextEditingController _localisationController = TextEditingController();
  final TextEditingController _prixController = TextEditingController();
  final TextEditingController _fournisseurTelController = TextEditingController();

  double? _fournisseurLatitude;
  double? _fournisseurLongitude;
  String _fournisseurAddress = '';
  String _fournisseurCity = '';
  bool _useSupplierCurrentLocation = false;
  bool _loadingSupplierAddress = false;
  bool _loadingPhone = true;
  
  // Variables pour l'upload d'images - Liste dynamique
  List<File?> _uploadedImages = [];
  List<String?> _cloudinaryUrls = [];
  List<bool> _isUploadingImage = [];

  // Variables pour l'upload de vidéo
  String? _cloudinaryVideoUrl;
  bool _isUploadingVideo = false;
  double _videoUploadProgress = 0.0;

  bool get _isAnyUploading => _isUploadingImage.contains(true) || _isUploadingVideo;
  bool _isSaving = false;

  final List<String> _pieceConditions = ['Nouveau', 'Occasion'];

  static const List<String> _oilViscosities = [
    '5W30',
    '10W40',
    '15W40',
    '5W40',
    '0W20',
    'Autre',
  ];
  static const List<String> _oilTypes = [
    'Synthétique',
    'Semi-synthétique',
    'Minérale',
  ];
  static const List<String> _oilVolumes = ['1L', '4L', '5L', '20L', 'Autre'];

  static const List<String> _tireVehicleTypes = [
    'Voiture',
    'Moto',
    'Camion',
    'SUV',
    'Autre',
  ];

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF2F2F2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initialData;
    if (widget.editMode && init != null) {
      _titleController.text = (init['titre'] ?? '').toString();
      _anneeController.text = (init['annee'] ?? '').toString();
      _prixController.text = (init['prix'] ?? '').toString();
      _marqueModeleController.text = (init['modele'] ?? '').toString();
      _selectedPieceCondition =
          (init['pieceType'] ?? init['condition'])?.toString();
      final cat = (init['categorie'] ?? '').toString().toLowerCase();
      if (cat == 'pneu') {
        _sellCategory = PieceSellCategory.pneu;
        _tireBrandController.text = (init['marque'] ?? '').toString();
        _tireModelController.text = (init['modele'] ?? '').toString();
        final titre = (init['titre'] ?? '').toString();
        final dimMatch = RegExp(r'(\d{2,3})/(\d{2,3})\s*(R?\d{2})')
            .firstMatch(titre);
        if (dimMatch != null) {
          _tireWidthController.text = dimMatch.group(1) ?? '';
          _tireHeightController.text = dimMatch.group(2) ?? '';
          _tireDiameterController.text = dimMatch.group(3) ?? '';
        }
        _initTireVehicleTypeFromEdit((init['typeMoteur'] ?? '').toString());
      } else if (cat == 'huile_moteur') {
        _sellCategory = PieceSellCategory.huileMoteur;
        _oilBrandController.text = (init['marque'] ?? '').toString();
        _oilCommercialNameController.text = (init['titre'] ?? '').toString();
        _initOilViscosityFromEdit((init['modele'] ?? '').toString());
        _selectedOilType = (init['typeMoteur'] ?? '').toString();
        final desc = (init['description'] ?? '').toString();
        _oilDescriptionController.text = desc;
        final volMatch =
            RegExp(r'Contenance:\s*([^·]+)').firstMatch(desc);
        _initOilVolumeFromEdit(
          volMatch?.group(1)?.trim() ?? '',
        );
      }
      if (init['photos'] is List) {
        final urls = (init['photos'] as List).map((e) => e?.toString()).whereType<String>().where((e) => e.isNotEmpty).toList();
        _cloudinaryUrls = urls.map((e) => e).toList();
        _uploadedImages = List<File?>.filled(_cloudinaryUrls.length, null);
        _isUploadingImage = List<bool>.filled(_cloudinaryUrls.length, false);
      }
      _cloudinaryVideoUrl = init['video']?.toString();
      _localisationController.text =
          (init['lieu'] ?? init['localisation'] ?? '').toString();
      final fournisseur = init['fournisseur'] is Map
          ? Map<String, dynamic>.from(init['fournisseur'] as Map)
          : <String, dynamic>{};
      _fournisseurTelController.text =
          (fournisseur['telephone'] ?? '').toString();
      final lat = fournisseur['latitude'];
      final lng = fournisseur['longitude'];
      _fournisseurLatitude = lat is num ? lat.toDouble() : double.tryParse('$lat');
      _fournisseurLongitude =
          lng is num ? lng.toDouble() : double.tryParse('$lng');
      _fournisseurAddress = (fournisseur['adresseTexte'] ?? '').toString();
      if (_fournisseurAddress.isEmpty) {
        _fournisseurAddress = _localisationController.text.trim();
      }
      _loadingPhone = false;
    } else {
      _loadLocationsFromProfile();
    }
  }

  Future<void> _loadLocationsFromProfile() async {
    setState(() => _loadingPhone = true);
    final profile = await SellerProfileLocations.load();
    if (!mounted) return;
    if (profile != null) {
      setState(() {
        _fournisseurTelController.text = profile.fournisseurTel;
        _fournisseurLatitude = profile.fournisseurLat;
        _fournisseurLongitude = profile.fournisseurLng;
        _fournisseurAddress = profile.fournisseurAddress;
        _fournisseurCity = profile.fournisseurCity;
        _localisationController.text = profile.fournisseurAddress;
        _loadingPhone = false;
      });
      return;
    }
    await _prefillSupplierPhone();
  }

  Future<void> _prefillSupplierPhone() async {
    if (widget.editMode && _fournisseurTelController.text.isNotEmpty) {
      if (mounted) setState(() => _loadingPhone = false);
      return;
    }
    try {
      final cached = await local_auth.AuthProvider.loadUserFromPrefs();
      final cachedTel = cached?['telephone']?.toString().trim() ?? '';
      if (cachedTel.isNotEmpty) {
        if (mounted) {
          setState(() {
            _fournisseurTelController.text = cachedTel;
            _loadingPhone = false;
          });
        }
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loadingPhone = false);
        return;
      }
      final idToken = await user.getIdToken();
      final resp = await Dio(
        BaseOptions(
          baseUrl: UserService().dio.options.baseUrl,
          headers: {'Authorization': 'Bearer $idToken'},
        ),
      ).get('/protected/me');
      final tel = resp.data['user']?['telephone']?.toString().trim() ?? '';
      if (mounted) {
        setState(() {
          if (tel.isNotEmpty) _fournisseurTelController.text = tel;
          _loadingPhone = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPhone = false);
    }
  }

  Future<void> _trackDemoEvent(String eventType, {String? page}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();
      log('[DEMO_EVENT] send $eventType page=$page');
      final dio = Dio(
        BaseOptions(
          baseUrl: UserService().dio.options.baseUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      final resp = await dio.post('/demo-events/track', data: {
        'eventType': eventType,
        'page': page,
        'client': 'mobile',
      });
      log('[DEMO_EVENT] resp status=${resp.statusCode} data=${resp.data}');
    } catch (_) {
      // best-effort
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final response = await Dio().get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': lat,
          'lon': lng,
          'zoom': 18,
          'addressdetails': 1,
        },
        options: Options(
          headers: {'User-Agent': 'TranooPro/1.0'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final address = data['display_name'] as String? ?? '';
        final city = data['address']?['city'] ??
            data['address']?['town'] ??
            data['address']?['village'] ??
            '';
        if (!mounted) return address;
        setState(() {
          _fournisseurCity = city?.toString() ?? '';
        });
        return address;
      }
    } catch (e) {
      log('[GEO] Reverse geocoding error: $e');
    }
    return '';
  }

  Future<void> _setSupplierLocation({
    required double lat,
    required double lng,
    required bool fromCurrent,
  }) async {
    if (!mounted) return;
    setState(() {
      _fournisseurLatitude = lat;
      _fournisseurLongitude = lng;
      _useSupplierCurrentLocation = fromCurrent;
      _loadingSupplierAddress = true;
    });
    final address = await _getAddressFromCoordinates(lat, lng);
    if (!mounted) return;
    setState(() {
      _fournisseurAddress = address;
      _loadingSupplierAddress = false;
    });
  }

  Future<void> _useCurrentSupplierLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => LocationPermissionDialog(
            userRole: 'vendeur',
            onPermissionGranted: () async {},
            onPermissionDenied: () {},
          ),
        );
        permission = await Geolocator.checkPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _setSupplierLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        fromCurrent: true,
      );
    } catch (e) {
      log('[GEO] Erreur position actuelle fournisseur: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _uploadedImages.removeAt(index);
      _cloudinaryUrls.removeAt(index);
      _isUploadingImage.removeAt(index);
    });
  }

  Future<void> _takePhotoFromCamera() async {
    if (_uploadedImages.length >= _maxMediaSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous avez atteint le maximum de 12 images')),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final file = File(image.path);
    final newIndex = _uploadedImages.length;

    setState(() {
      _uploadedImages.add(file);
      _cloudinaryUrls.add(null);
      _isUploadingImage.add(true);
    });

    try {
      final url = await uploadImageToCloudinary(
        file,
        folder: CloudinaryFolders.pieceImages,
      );
      if (!mounted) return;
      if (url != null) {
        setState(() {
          _cloudinaryUrls[newIndex] = url;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'upload de l\'image.')),
        );
        setState(() {
          _uploadedImages.removeAt(newIndex);
          _cloudinaryUrls.removeAt(newIndex);
          _isUploadingImage.removeAt(newIndex);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload échoué: $e')),
      );
      setState(() {
        _uploadedImages.removeAt(newIndex);
        _cloudinaryUrls.removeAt(newIndex);
        _isUploadingImage.removeAt(newIndex);
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingImage[newIndex] = false;
      });
    }
  }

  Future<void> _uploadGalleryFile(File file) async {
    if (_uploadedImages.length >= _maxMediaSlots) return;

    final newIndex = _uploadedImages.length;
    setState(() {
      _uploadedImages.add(file);
      _cloudinaryUrls.add(null);
      _isUploadingImage.add(true);
    });

    try {
      final url = await uploadImageToCloudinary(
        file,
        folder: CloudinaryFolders.pieceImages,
      );
      if (!mounted) return;
      if (url != null) {
        setState(() {
          _cloudinaryUrls[newIndex] = url;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'upload de l\'image.')),
        );
        setState(() {
          _uploadedImages.removeAt(newIndex);
          _cloudinaryUrls.removeAt(newIndex);
          _isUploadingImage.removeAt(newIndex);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload échoué: $e')),
      );
      setState(() {
        _uploadedImages.removeAt(newIndex);
        _cloudinaryUrls.removeAt(newIndex);
        _isUploadingImage.removeAt(newIndex);
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingImage[newIndex] = false;
      });
    }
  }

  Future<void> _pickMultipleImages() async {
    if (_uploadedImages.length >= _maxMediaSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous avez atteint le maximum de 12 images')),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile>? images = await picker.pickMultiImage();
      if (images == null || images.isEmpty) return;

      for (final image in images) {
        if (_uploadedImages.length >= _maxMediaSlots) break;
        await _uploadGalleryFile(File(image.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectionError(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeVideo() {
    setState(() {
      _cloudinaryVideoUrl = null;
      _isUploadingVideo = false;
    });
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    // Vérification de la taille (500 Mo max)
    final int maxSizeBytes = 500 * 1024 * 1024;
    final int videoSize = await video.length();
    final double videoSizeMB = videoSize / (1024 * 1024);

    if (videoSize > maxSizeBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La vidéo est trop lourde (${videoSizeMB.toStringAsFixed(2)} Mo). Limite: 500 Mo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploadingVideo = true;
      _videoUploadProgress = 0.0;
    });

    try {
      final url = await uploadVideoToCloudinary(
        File(video.path),
        folder: CloudinaryFolders.pieceVideos,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _videoUploadProgress = progress;
          });
        },
      );
      if (!mounted) return;
      if (url != null) {
        setState(() {
          _cloudinaryVideoUrl = url;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.videoUploadedSuccess), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'upload de la vidéo.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload vidéo échoué: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingVideo = false;
        _videoUploadProgress = 0.0;
      });
    }
  }

  Widget _buildLabel(String text, {bool isRequired = true}) {
    return Text(
      isRequired ? '$text *' : text,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String value)? itemLabel,
  }) {
    final resolved = (value != null && value.isNotEmpty)
        ? (items.contains(value) ? value : (items.contains('Autre') ? 'Autre' : null))
        : null;
    return DropdownButtonFormField<String>(
      value: resolved,
      isExpanded: true,
      decoration: _inputDecoration(hint),
      items: items
          .map(
            (e) => DropdownMenuItem<String>(
              value: e,
              child: Text(itemLabel != null ? itemLabel(e) : e),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  String _oilViscosityValue() {
    if (_selectedOilViscosity == 'Autre') {
      return _oilViscosityOtherController.text.trim();
    }
    return _selectedOilViscosity ?? '';
  }

  String _oilVolumeValue() {
    if (_selectedOilVolume == 'Autre') {
      return _oilVolumeOtherController.text.trim();
    }
    return _selectedOilVolume ?? '';
  }

  String _tireVehicleTypeValue() {
    if (_selectedTireVehicleType == 'Autre') {
      return _tireVehicleTypeOtherController.text.trim();
    }
    return _selectedTireVehicleType ?? '';
  }

  void _initOilViscosityFromEdit(String raw) {
    if (raw.isEmpty) return;
    if (_oilViscosities.contains(raw)) {
      _selectedOilViscosity = raw;
    } else {
      _selectedOilViscosity = 'Autre';
      _oilViscosityOtherController.text = raw;
    }
  }

  void _initOilVolumeFromEdit(String raw) {
    if (raw.isEmpty) return;
    if (_oilVolumes.contains(raw)) {
      _selectedOilVolume = raw;
    } else {
      _selectedOilVolume = 'Autre';
      _oilVolumeOtherController.text = raw;
    }
  }

  void _initTireVehicleTypeFromEdit(String raw) {
    if (raw.isEmpty) return;
    if (_tireVehicleTypes.contains(raw)) {
      _selectedTireVehicleType = raw;
    } else {
      _selectedTireVehicleType = 'Autre';
      _tireVehicleTypeOtherController.text = raw;
    }
  }

  String _categoryLabel(PieceSellCategory cat) => switch (cat) {
        PieceSellCategory.pieceDetachee => 'Pièce détachée',
        PieceSellCategory.pneu => 'Pneu',
        PieceSellCategory.huileMoteur => 'Huile moteur',
      };

  Widget _buildArticleTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Type d'article"),
        const SizedBox(height: 8),
        _buildDropdown(
          hint: 'Choisir le type',
          value: _sellCategory.name,
          items: PieceSellCategory.values.map((c) => c.name).toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _sellCategory = PieceSellCategory.values.firstWhere(
                (c) => c.name == v,
              );
            });
          },
          itemLabel: (v) => _categoryLabel(
            PieceSellCategory.values.firstWhere((c) => c.name == v),
          ),
        ),
      ],
    );
  }

  Widget _buildPieceDetacheeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Nom de la pièce'),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: _inputDecoration('Nom de la pièce'),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('État'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _pieceConditions.map((type) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<String>(
                            value: type,
                            groupValue: _selectedPieceCondition,
                            onChanged: (value) =>
                                setState(() => _selectedPieceCondition = value),
                            activeColor: Colors.amber,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          Text(type, style: const TextStyle(fontSize: 14)),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Année', isRequired: false),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _anneeController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Ex: 2020 (optionnel)'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildLabel('Marque & modèle'),
        const SizedBox(height: 8),
        TextField(
          controller: _marqueModeleController,
          decoration: _inputDecoration('Ex: Toyota Corolla, Honda Civic...'),
        ),
      ],
    );
  }

  Widget _buildHuileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Marque'),
        const SizedBox(height: 8),
        TextField(
          controller: _oilBrandController,
          decoration: _inputDecoration('Total, Shell, Castrol...'),
        ),
        const SizedBox(height: 20),
        _buildLabel('Nom commercial'),
        const SizedBox(height: 8),
        TextField(
          controller: _oilCommercialNameController,
          decoration: _inputDecoration('Ex: Quartz 9000, Helix Ultra...'),
        ),
        const SizedBox(height: 20),
        _buildLabel('Viscosité'),
        const SizedBox(height: 8),
        _buildDropdown(
          hint: 'Choisir la viscosité',
          value: _selectedOilViscosity,
          items: _oilViscosities,
          onChanged: (v) => setState(() => _selectedOilViscosity = v),
        ),
        if (_selectedOilViscosity == 'Autre') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _oilViscosityOtherController,
            decoration: _inputDecoration('Précisez la viscosité'),
          ),
        ],
        const SizedBox(height: 20),
        _buildLabel('Type'),
        const SizedBox(height: 8),
        _buildDropdown(
          hint: 'Choisir le type',
          value: _selectedOilType,
          items: _oilTypes,
          onChanged: (v) => setState(() => _selectedOilType = v),
        ),
        const SizedBox(height: 20),
        _buildLabel('Contenance'),
        const SizedBox(height: 8),
        _buildDropdown(
          hint: 'Choisir la contenance',
          value: _selectedOilVolume,
          items: _oilVolumes,
          onChanged: (v) => setState(() => _selectedOilVolume = v),
        ),
        if (_selectedOilVolume == 'Autre') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _oilVolumeOtherController,
            decoration: _inputDecoration('Ex: 2L, 10L...'),
          ),
        ],
        const SizedBox(height: 20),
        _buildLabel('Description', isRequired: false),
        const SizedBox(height: 8),
        TextField(
          controller: _oilDescriptionController,
          maxLines: 3,
          decoration: _inputDecoration('Informations complémentaires (optionnel)'),
        ),
      ],
    );
  }

  Widget _buildPneuForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Marque'),
        const SizedBox(height: 8),
        TextField(
          controller: _tireBrandController,
          decoration: _inputDecoration('Michelin, Bridgestone, Goodyear...'),
        ),
        const SizedBox(height: 20),
        _buildLabel('Référence / Modèle'),
        const SizedBox(height: 8),
        TextField(
          controller: _tireModelController,
          decoration: _inputDecoration('Ex: Pilot Sport 4, Turanza...'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Dimensions',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Largeur'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tireWidthController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('205'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Hauteur'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tireHeightController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('55'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Diamètre'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tireDiameterController,
                    decoration: _inputDecoration('R16'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildLabel('Type de véhicule'),
        const SizedBox(height: 8),
        _buildDropdown(
          hint: 'Voiture, Moto, Camion...',
          value: _selectedTireVehicleType,
          items: _tireVehicleTypes,
          onChanged: (v) => setState(() => _selectedTireVehicleType = v),
        ),
        if (_selectedTireVehicleType == 'Autre') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _tireVehicleTypeOtherController,
            decoration: _inputDecoration('Précisez le type de véhicule'),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryForm() {
    return switch (_sellCategory) {
      PieceSellCategory.pieceDetachee => _buildPieceDetacheeForm(),
      PieceSellCategory.huileMoteur => _buildHuileForm(),
      PieceSellCategory.pneu => _buildPneuForm(),
    };
  }

  Widget _buildPriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Prix'),
        const SizedBox(height: 8),
        TextField(
          controller: _prixController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            ...decimalOptionalInputFormatters,
            LengthLimitingTextInputFormatter(14),
          ],
          decoration: _inputDecoration('Prix en FCFA'),
        ),
      ],
    );
  }

  bool _validateForm() {
    final prix = _prixController.text.trim();
    final phone = _fournisseurTelController.text.trim();
    if (prix.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fillRequiredFields)),
      );
      return false;
    }

    switch (_sellCategory) {
      case PieceSellCategory.pieceDetachee:
        if (_titleController.text.trim().isEmpty ||
            _selectedPieceCondition == null ||
            _marqueModeleController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.fillRequiredFields)),
          );
          return false;
        }
      case PieceSellCategory.huileMoteur:
        if (_oilBrandController.text.trim().isEmpty ||
            _oilCommercialNameController.text.trim().isEmpty ||
            _selectedOilViscosity == null ||
            _oilViscosityValue().isEmpty ||
            _selectedOilType == null ||
            _selectedOilVolume == null ||
            _oilVolumeValue().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.fillRequiredFields)),
          );
          return false;
        }
      case PieceSellCategory.pneu:
        if (_tireBrandController.text.trim().isEmpty ||
            _tireModelController.text.trim().isEmpty ||
            _tireWidthController.text.trim().isEmpty ||
            _tireHeightController.text.trim().isEmpty ||
            _tireDiameterController.text.trim().isEmpty ||
            _selectedTireVehicleType == null ||
            _tireVehicleTypeValue().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.fillRequiredFields)),
          );
          return false;
        }
    }
    return true;
  }

  ({
    String title,
    String year,
    String description,
    String company,
    String model,
    String? pieceType,
    String? fuelType,
    String categorie,
    String marque,
  }) _buildListingData() {
    switch (_sellCategory) {
      case PieceSellCategory.pieceDetachee:
        return (
          title: _titleController.text.trim(),
          year: _anneeController.text.trim(),
          description: '',
          company: '',
          model: _marqueModeleController.text.trim(),
          pieceType: _selectedPieceCondition,
          fuelType: null,
          categorie: 'piece_detachee',
          marque: '',
        );
      case PieceSellCategory.huileMoteur:
        final desc = _oilDescriptionController.text.trim();
        final volume = _oilVolumeValue();
        final viscosity = _oilViscosityValue();
        final meta = 'Contenance: $volume · Type: $_selectedOilType';
        return (
          title: _oilCommercialNameController.text.trim(),
          year: '',
          description: desc.isEmpty ? meta : '$desc\n$meta',
          company: '',
          model: viscosity,
          pieceType: null,
          fuelType: _selectedOilType,
          categorie: 'huile_moteur',
          marque: _oilBrandController.text.trim(),
        );
      case PieceSellCategory.pneu:
        final width = _tireWidthController.text.trim();
        final height = _tireHeightController.text.trim();
        final diameter = _tireDiameterController.text.trim();
        final dims = '$width/$height $diameter';
        final vehicleType = _tireVehicleTypeValue();
        return (
          title:
              '${_tireBrandController.text.trim()} ${_tireModelController.text.trim()} $dims'
                  .trim(),
          year: '',
          description: 'Véhicule: $vehicleType',
          company: '',
          model: _tireModelController.text.trim(),
          pieceType: null,
          fuelType: vehicleType,
          categorie: 'pneu',
          marque: _tireBrandController.text.trim(),
        );
    }
  }

  // Widget vidéo identique à celui de create_sell
  Widget _buildVideoSection() {
    return Container(
      height: 150,
      width: double.infinity,
      child: GestureDetector(
        onTap: _cloudinaryVideoUrl != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Movie(videoUrl: _cloudinaryVideoUrl!),
                  ),
                );
              }
            : _pickVideo,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _cloudinaryVideoUrl != null ? Colors.green : Colors.blue,
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_cloudinaryVideoUrl != null)
                Container(
                  color: Colors.black87,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      Text(l10n.videoReady, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.video_call, color: Colors.grey, size: 40),
                    const SizedBox(height: 6),
                    const Text('Ajouter une vidéo', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(l10n.tapToAddVideo, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              if (_isUploadingVideo)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              value: _videoUploadProgress > 0 ? _videoUploadProgress : null,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _videoUploadProgress < 0.85 ? 'Envoi...' : 'Traitement...',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(_videoUploadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_cloudinaryVideoUrl != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: _removeVideo,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileFournisseurSummary() {
    if (_loadingPhone) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Chargement du profil...', style: TextStyle(color: Colors.black54)),
      );
    }
    final hasLoc =
        _fournisseurLatitude != null && _fournisseurLongitude != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fournisseurTelController.text.isNotEmpty
                ? 'Tél. ${_fournisseurTelController.text}'
                : 'Téléphone non renseigné — complétez votre profil',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _fournisseurTelController.text.isNotEmpty
                  ? Colors.black87
                  : Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          if (hasLoc)
            Text(
              _fournisseurAddress.isNotEmpty
                  ? truncateWithEllipsis(_fournisseurAddress)
                  : 'Position GPS enregistrée',
              style: const TextStyle(fontSize: 13),
            )
          else
            const Text(
              'Localisation manquante — mettez à jour votre position dans le profil.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationButton(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      child: ElevatedButton(
        onPressed: (_isAnyUploading || _isSaving) ? null : _onValidate,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFCC00),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: (_isAnyUploading || _isSaving)
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isSaving
                        ? 'Enregistrement...'
                        : 'Upload en cours...',
                  ),
                ],
              )
            : Text(
                widget.editMode ? 'Sauvegarder' : 'Aperçu',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Future<void> _onValidate() async {
    if (!widget.editMode) {
      _trackDemoEvent('seller_create_started', page: 'create_sell2.dart');
    }
    if (!_validateForm()) return;

    final data = _buildListingData();
    final prix = _prixController.text.trim();

    final imagesCount = _cloudinaryUrls.whereType<String>().where((url) => url.isNotEmpty).length;
    final hasImages = imagesCount > 0;
    final hasVideo = _cloudinaryVideoUrl != null && _cloudinaryVideoUrl!.isNotEmpty;
    
    if (!hasImages && !hasVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addAtLeastOneMedia)),
      );
      return;
    }

    if (!widget.editMode) {
      _trackDemoEvent('seller_create_completed', page: 'create_sell2.dart');
    }

    final images = _cloudinaryUrls.whereType<String>().where((url) => url.isNotEmpty).toList();
    final locInput = _localisationController.text.trim().isNotEmpty
        ? _localisationController.text.trim()
        : _fournisseurAddress;
    final resolvedLoc = locInput.isNotEmpty
        ? await resolveLocationInput(locInput)
        : const ResolvedLocation(localisation: '', lieu: '');
    if (resolvedLoc.geocoded && resolvedLoc.localisation.isNotEmpty) {
      _localisationController.text = resolvedLoc.localisation;
      _fournisseurAddress = resolvedLoc.localisation;
    }
    final fournisseur = {
      'telephone': _fournisseurTelController.text.trim(),
      'latitude': _fournisseurLatitude,
      'longitude': _fournisseurLongitude,
      'adresseTexte': resolvedLoc.localisation.isNotEmpty
          ? resolvedLoc.localisation
          : _fournisseurAddress,
    };

    if (widget.editMode) {
      _saveEditedPiece(
        title: data.title,
        annee: data.year,
        description: data.description,
        company: data.company,
        prix: prix,
        model: data.model,
        pieceType: data.pieceType,
        fuelType: data.fuelType,
        categorie: data.categorie,
        marque: data.marque,
        images: images,
        video: _cloudinaryVideoUrl,
        fournisseur: fournisseur,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MastervacPage(
          isAcheteur: false,
          title: data.title,
          year: data.year,
          description: data.description,
          company: data.company,
          location: resolvedLoc.localisation.isNotEmpty
              ? resolvedLoc.localisation
              : (_fournisseurAddress.isNotEmpty ? _fournisseurAddress : null),
          price: prix,
          model: data.model,
          pieceType: data.pieceType,
          fuelType: data.fuelType,
          categorie: data.categorie,
          marque: data.marque,
          images: images,
          video: _cloudinaryVideoUrl,
          fournisseur: fournisseur,
          alertNotificationId: widget.alertNotificationId,
          alertBuyerId: widget.alertBuyerId,
          alertRequestType: widget.alertRequestType,
        ),
      ),
    );
  }

  Future<void> _saveEditedPiece({
    required String title,
    required String annee,
    required String description,
    required String company,
    required String prix,
    required String model,
    required String? pieceType,
    required String? fuelType,
    required String categorie,
    required String marque,
    required List<String> images,
    required String? video,
    required Map<String, dynamic> fournisseur,
  }) async {
    final id = (widget.editArticleId ?? '').toString();
    if (id.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return;
      final locInput = _localisationController.text.trim();
      final resolved = locInput.isNotEmpty
          ? await resolveLocationInput(locInput)
          : const ResolvedLocation(localisation: '', lieu: '');
      final lieuValue = resolved.localisation.isNotEmpty
          ? resolved.localisation
          : locInput;
      final payload = {
        'type': 'piece',
        'titre': title,
        'annee': annee,
        'description': description,
        'entreprise': company,
        'prix': prix,
        'modele': model,
        'marque': marque,
        'categorie': categorie,
        if (pieceType != null) 'condition': pieceType,
        if (fuelType != null) 'typeMoteur': fuelType,
        'photos': images,
        'video': video,
        'fournisseur': fournisseur,
        'lieu': lieuValue,
        'localisation': lieuValue,
      };
      final resp = await Dio().put(
        '${UserService().dio.options.baseUrl}/articles/$id',
        data: payload,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (!mounted) return;
      if ((resp.statusCode ?? 500) >= 200 && (resp.statusCode ?? 500) < 300) {
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGES
                    _buildLabel('Images (max 12)', isRequired: false),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickMultipleImages,
                            icon: const Icon(Icons.add_photo_alternate, size: 20),
                            label: Text(
                              'Ajouter des images (${_uploadedImages.length}/$_maxMediaSlots)',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF8BF13),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Prendre une photo',
                          onPressed: _takePhotoFromCamera,
                          icon: const Icon(Icons.photo_camera),
                          color: const Color(0xFFF8BF13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Affichage des images uploadées
                    if (_uploadedImages.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _uploadedImages.length,
                          itemBuilder: (context, index) {
                            final file = _uploadedImages[index];
                            final uploadedUrl = _cloudinaryUrls[index];
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (uploadedUrl != null && uploadedUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedMediaImage(
                                        url: uploadedUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        cloudinaryWidthPx: 400,
                                        errorWidget: const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    )
                                  else if (file != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                    )
                                  else
                                    const Icon(Icons.image, color: Colors.grey),
                                  if (_isUploadingImage[index])
                                    const Positioned.fill(
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                  if (uploadedUrl != null && uploadedUrl.isNotEmpty)
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),
                    
                    // VIDÉO
                    _buildLabel('Vidéo (optionnelle, max 500 Mo)', isRequired: false),
                    const SizedBox(height: 8),
                    _buildVideoSection(),
                    const SizedBox(height: 24),

                    _buildArticleTypeSelector(),
                    const SizedBox(height: 20),
                    _buildCategoryForm(),
                    const SizedBox(height: 20),
                    _buildPriceField(),
                    const SizedBox(height: 24),

                    const Text(
                      'Fournisseur (profil)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Téléphone et localisation repris de votre inscription. '
                      'Mettez à jour votre profil si besoin.',
                      style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    CountryLocationField(
                      controller: _localisationController,
                      label: 'Localisation',
                      hint: 'Pays ou Ville, Pays (ex. Cotonou, Bénin)',
                      onChanged: (v) => _fournisseurAddress = v.trim(),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileFournisseurSummary(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // Bouton Aperçu toujours visible
            _buildVerificationButton(context),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _anneeController.dispose();
    _localisationController.dispose();
    _prixController.dispose();
    _fournisseurTelController.dispose();
    _marqueModeleController.dispose();
    _oilCommercialNameController.dispose();
    _oilDescriptionController.dispose();
    _oilBrandController.dispose();
    _oilViscosityOtherController.dispose();
    _oilVolumeOtherController.dispose();
    _tireBrandController.dispose();
    _tireModelController.dispose();
    _tireWidthController.dispose();
    _tireHeightController.dispose();
    _tireDiameterController.dispose();
    _tireVehicleTypeOtherController.dispose();
    super.dispose();
  }
}