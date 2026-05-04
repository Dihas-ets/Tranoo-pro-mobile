import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

import 'mastervacpage.dart';
import '../../utils/cloudinary_upload.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'dart:developer';
import 'map_picker_screen.dart';
import '../../widgets/location_permission_dialog.dart';
import 'movie.dart';

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
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  
  // Infos fournisseur
  final TextEditingController _fournisseurTelController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  double? _fournisseurLatitude;
  double? _fournisseurLongitude;
  String _fournisseurAddress = '';
  String _fournisseurCity = '';
  bool _useSupplierCurrentLocation = false;
  bool _loadingSupplierAddress = false;
  String? _selectedPieceType;
  String? _selectedFuelType;
  
  // Variables pour l'upload d'images - Liste dynamique
  List<File?> _uploadedImages = [];
  List<String?> _cloudinaryUrls = [];
  List<bool> _isUploadingImage = [];

  // Variables pour l'upload de vidéo
  String? _cloudinaryVideoUrl;
  bool _isUploadingVideo = false;
  double _videoUploadProgress = 0.0;

  bool get _isAnyUploading => _isUploadingImage.contains(true) || _isUploadingVideo;

  final List<String> _pieceTypes = ['Nouveau', 'Occasion'];
  final List<String> _fuelTypes = [
    'Essence',
    'Gazoil',
    'Diesel',
    'Electrique',
    'Hybride',
    'Aucun',
  ];
  String? _customFuelType;

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
      _descriptionController.text = (init['description'] ?? '').toString();
      _companyController.text = (init['entreprise'] ?? '').toString();
      _modelController.text = (init['modele'] ?? '').toString();
      _selectedPieceType = (init['pieceType'] ?? init['condition'])?.toString();
      _selectedFuelType = (init['typeMoteur'] ?? '').toString().isNotEmpty
          ? (init['typeMoteur']).toString()
          : null;
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

  Future<void> _addNewImage() async {
    if (_uploadedImages.length >= _maxMediaSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous avez atteint le maximum de 12 images')),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
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
          const SnackBar(content: Text('Vidéo uploadée avec succès !'), backgroundColor: Colors.green),
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
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          items: items.map((String item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
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
                      Text('Vidéo prête', style: TextStyle(color: Colors.white)),
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
                    const Text('Appuyer pour ajouter', style: TextStyle(color: Colors.grey, fontSize: 11)),
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

  Widget _buildVerificationButton(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      child: ElevatedButton(
        onPressed: _isAnyUploading ? null : _onValidate,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFCC00),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: _isAnyUploading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Upload en cours...'),
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
    final description = _descriptionController.text.trim().isNotEmpty 
        ? _descriptionController.text.trim() 
        : 'Description non renseignée';
    final company = _companyController.text.trim();
    final pieceType = _selectedPieceType;
    final fuelType = _selectedFuelType == 'Aucun' ? _customFuelType : _selectedFuelType;
    final model = _modelController.text.trim();

    if (title.isEmpty ||
        pieceType == null ||
        annee.isEmpty ||
        (fuelType == null || fuelType.isEmpty) ||
        model.isEmpty ||
        prix.isEmpty ||
        company.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires.')),
      );
      return;
    }

    final imagesCount = _cloudinaryUrls.whereType<String>().where((url) => url.isNotEmpty).length;
    final hasImages = imagesCount > 0;
    final hasVideo = _cloudinaryVideoUrl != null && _cloudinaryVideoUrl!.isNotEmpty;
    
    if (!hasImages && !hasVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins une image ou une vidéo.')),
      );
      return;
    }

    if (!widget.editMode) {
      _trackDemoEvent('seller_create_completed', page: 'create_sell2.dart');
    }

    final images = _cloudinaryUrls.whereType<String>().where((url) => url.isNotEmpty).toList();
    final fournisseur = {
      'telephone': _fournisseurTelController.text.trim(),
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
        fuelType: fuelType,
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
          fuelType: fuelType,
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
    required String? fuelType,
    required String model,
    required String? pieceType,
    required List<String> images,
    required String? video,
    required Map<String, dynamic> fournisseur,
  }) async {
    final id = (widget.editArticleId ?? '').toString();
    if (id.isEmpty) return;
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
        'typeMoteur': fuelType,
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
          const SnackBar(content: Text('Modifications enregistrées.')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sauvegarde: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sauvegarde: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGES
                    _buildLabel('Images (max 12)', isRequired: false),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addNewImage,
                        icon: const Icon(Icons.add_photo_alternate, size: 20),
                        label: Text('Ajouter des images (${_uploadedImages.length}/$_maxMediaSlots)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8BF13),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
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

                    // Infos fournisseur
                    const Text('Informations du fournisseur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _buildLabel('Téléphone'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _fournisseurTelController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('Téléphone du fournisseur'),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Localisation fournisseur'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _useCurrentSupplierLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Position actuelle'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push<Map<String, double>>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapPickerScreen(
                                    initialLatitude: _fournisseurLatitude,
                                    initialLongitude: _fournisseurLongitude,
                                  ),
                                ),
                              );
                              if (result != null) {
                                final lat = result['latitude'];
                                final lng = result['longitude'];
                                if (lat != null && lng != null) {
                                  await _setSupplierLocation(lat: lat, lng: lng, fromCurrent: false);
                                }
                              }
                            },
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Choisir sur carte'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_fournisseurLatitude != null && _fournisseurLongitude != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCC00).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.65)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_useSupplierCurrentLocation ? Icons.my_location : Icons.map, size: 16, color: const Color(0xFFB45309)),
                                const SizedBox(width: 8),
                                Text(
                                  _useSupplierCurrentLocation ? 'Position actuelle' : 'Position sélectionnée',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                                ),
                                if (_fournisseurCity.isNotEmpty) ...[
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFFFFCC00), borderRadius: BorderRadius.circular(12)),
                                    child: Text(_fournisseurCity, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_loadingSupplierAddress)
                              const Text('Récupération de l\'adresse...', style: TextStyle(color: Colors.black54))
                            else
                              Text(_fournisseurAddress.isNotEmpty ? _fournisseurAddress : 'Adresse non disponible', style: const TextStyle(color: Colors.black87)),
                          ],
                        ),
                      )
                    else
                      const Text('Localisation fournisseur non définie', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                              _buildLabel('Année'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _anneeController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Ex: 2020'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Type moteur et Modèle
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Type de moteur'),
                              const SizedBox(height: 8),
                              _buildDropdown(
                                value: _selectedFuelType,
                                hint: 'Type de moteur',
                                items: _fuelTypes,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedFuelType = value;
                                    if (value != 'Aucun') _customFuelType = null;
                                  });
                                },
                              ),
                              if (_selectedFuelType == 'Aucun')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: TextField(
                                    decoration: _inputDecoration('Précisez le type'),
                                    onChanged: (val) => setState(() => _customFuelType = val),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Modèle'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _modelController,
                                decoration: _inputDecoration('Ex: Corolla, Hilux...'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Prix
                    _buildLabel('Prix'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _prixController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Prix en FCFA'),
                    ),
                    const SizedBox(height: 20),

                    // Description (optionnelle)
                    _buildLabel('Description de la pièce', isRequired: false),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: _inputDecoration('Description (optionnel)'),
                    ),
                    const SizedBox(height: 20),

                    // Nom de l'entreprise
                    _buildLabel('Nom de l\'entreprise'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _companyController,
                      decoration: _inputDecoration('Nom de l\'entreprise'),
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
    _descriptionController.dispose();
    _companyController.dispose();
    _fournisseurTelController.dispose();
    _modelController.dispose();
    super.dispose();
  }
}