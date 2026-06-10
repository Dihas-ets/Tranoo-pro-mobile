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
  static const int _maxMediaSlots = 12;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _anneeController = TextEditingController();
  final TextEditingController _localisationController = TextEditingController();
  final TextEditingController _prixController = TextEditingController();
  // Infos fournisseur
  final TextEditingController _fournisseurTelController = TextEditingController();
  final TextEditingController _marqueModeleController = TextEditingController();
  double? _fournisseurLatitude;
  double? _fournisseurLongitude;
  String _fournisseurAddress = '';
  String _fournisseurCity = '';
  bool _useSupplierCurrentLocation = false;
  bool _loadingSupplierAddress = false;
  String? _selectedPieceType;
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

  final List<String> _pieceTypes = ['Nouveau', 'Occasion'];

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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
      _selectedPieceType = (init['pieceType'] ?? init['condition'])?.toString();
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
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                      SizedBox(height: 8),
                      Text(l10n.videoReady, style: TextStyle(color: Colors.white)),
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

  void _onValidate() {
    if (!widget.editMode) {
      _trackDemoEvent('seller_create_started', page: 'create_sell2.dart');
    }
    final title = _titleController.text.trim();
    final annee = _anneeController.text.trim();
    final prix = _prixController.text.trim();
    const description = '';
    const company = '';
    final pieceType = _selectedPieceType;
    final model = _marqueModeleController.text.trim();
    final phone = _fournisseurTelController.text.trim();

    if (title.isEmpty ||
        pieceType == null ||
        model.isEmpty ||
        prix.isEmpty ||
        phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fillRequiredFields)),
      );
      return;
    }

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
    final fournisseur = {
      'telephone': phone,
      'latitude': _fournisseurLatitude,
      'longitude': _fournisseurLongitude,
      'adresseTexte': _fournisseurAddress.isNotEmpty
          ? _fournisseurAddress
          : _localisationController.text.trim(),
    };

    if (widget.editMode) {
      _saveEditedPiece(
        title: title,
        annee: annee,
        description: description,
        company: company,
        prix: prix,
        model: model,
        pieceType: pieceType,
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
          title: title,
          year: annee,
          description: description,
          company: company,
          location: _fournisseurAddress.isNotEmpty ? _fournisseurAddress : null,
          price: prix,
          model: model,
          pieceType: pieceType,
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
      final payload = {
        'type': 'piece',
        'titre': title,
        'annee': annee,
        'description': description,
        'entreprise': company,
        'prix': prix,
        'modele': model,
        'pieceType': pieceType,
        'photos': images,
        'video': video,
        'fournisseur': fournisseur,
        'lieu': _localisationController.text.trim(),
        'localisation': _localisationController.text.trim(),
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
                                      child: Image.network(
                                        uploadedUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
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
                    
                    // Titre
                    _buildLabel('Nom de la pièce'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: _inputDecoration('Nom de la pièce'),
                    ),
                    const SizedBox(height: 20),

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
                    _buildProfileFournisseurSummary(),
                    const SizedBox(height: 20),

                    // Type et Année
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Type'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: _pieceTypes.map((type) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<String>(
                                        value: type,
                                        groupValue: _selectedPieceType,
                                        onChanged: (value) => setState(() => _selectedPieceType = value),
                                        activeColor: Colors.amber,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    const SizedBox(height: 20),

                    // Prix
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
    super.dispose();
  }
}