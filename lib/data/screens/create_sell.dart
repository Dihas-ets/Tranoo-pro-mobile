import 'dart:io';
import 'dart:typed_data'; // Added for Uint8List
import 'dart:convert'; // Added for jsonDecode
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Added for kIsWeb
import 'package:flutter/services.dart'; // Added for input formatters
import 'package:image_picker/image_picker.dart';
import '../../utils/cloudinary_upload.dart';
import 'package:http/http.dart' as http; // Ajouté pour l'upload web
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import 'cars_info.dart'; // Importer le fichier combiné cars_info
import 'map_picker_screen.dart';
import '../../widgets/location_permission_dialog.dart';
import 'movie.dart';
import 'package:tranoo_pro/utils/amount_display.dart';
import 'package:tranoo_pro/services/seller_profile_locations.dart';

class CreateSellPage extends StatefulWidget {
  final String? alertNotificationId;
  final String? alertBuyerId;
  final String? alertRequestType;
  final bool editMode;
  final String? editArticleId;
  final Map<String, dynamic>? initialData;

  const CreateSellPage({
    super.key,
    this.alertNotificationId,
    this.alertBuyerId,
    this.alertRequestType,
    this.editMode = false,
    this.editArticleId,
    this.initialData,
  });

  @override
  // ignore: library_private_types_in_public_api
  _CreateSellPageState createState() => _CreateSellPageState();
}

class _CreateSellPageState extends State<CreateSellPage> {
  static const int _maxMediaSlots = 12;
  static const int _maxVideoSlots = 3;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _cylindreController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _siegesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String? _selectedCondition; // Gardé en String pour "Nouveau" et "Occasion"
  String? _selectedModel; // Modèle
  String? _selectedMarques;
  int? _selectedPorte; // Portes
  String? _selectedBoiteVitesse;
  String? _selectedCarburantDropdown;
  String? _selectedClimatiseurDropdown;
  // File? _uploadedImage;
  String? _uploadedFileName;
  //bool _hasUploadedFile = false;
  final bool _hasUploadedFile = false;
  String? _cloudinaryUrl;

  /// Localisation véhicule (carte / GPS), alignée sur create_sell2.
  double? _vehicleLatitude;
  double? _vehicleLongitude;
  String _vehicleAddress = '';
  String _vehicleCity = '';
  bool _useVehicleCurrentLocation = false;
  bool _loadingVehicleAddress = false;

  // Ajout pour plusieurs images et vidéo
  List<File?> _uploadedImages =
      List.filled(_maxMediaSlots, null); // mobile - max images
  List<Uint8List?> _uploadedImagesWeb = List.filled(
    _maxMediaSlots,
    null,
  ); // web - max images
  List<String?> _cloudinaryImageUrls = List.filled(_maxMediaSlots, null);
  List<bool> _isUploadingImage = List.filled(
    _maxMediaSlots,
    false,
  ); // Ajouté pour le chargement
  final PageController _videoPageController = PageController();
  int _currentVideoIndex = 0;
  List<File?> _uploadedVideos = List.filled(_maxVideoSlots, null);
  List<String?> _cloudinaryVideoUrls = List.filled(_maxVideoSlots, null);
  List<bool> _isUploadingVideo = List.filled(_maxVideoSlots, false);
  List<double> _videoUploadProgress =
      List.filled(_maxVideoSlots, 0.0); // Progression de l'upload vidéo

  String? _customModel; // Ajouté pour la saisie personnalisée du modèle
  String? _customMarque; // Ajouté pour la saisie personnalisée de la marque
  String? _selectedCouleur; // Couleur sélectionnée

  final List<String> _conditions = ['Nouveau', 'Occasion']; // Reste en String

  // Mapping des marques vers leurs modèles
  final Map<String, List<String>> _marqueModels = {
    'BMW': ['Série 3', 'Série 5', 'X3', 'X5', 'Série 1', 'Autre'],
    'Mercedes': ['Classe C', 'Classe E', 'GLC', 'GLE', 'Classe A', 'Autre'],
    'Audi': ['A3', 'A4', 'A6', 'Q5', 'Q7', 'Autre'],
    'Ford': ['Focus', 'Fiesta', 'Ranger', 'Explorer', 'Mustang', 'Autre'],
    'Lexus': ['IS', 'ES', 'RX', 'NX', 'LS', 'Autre'],
  };

  final List<String> _marques = [
    'BMW',
    'Mercedes',
    'Audi',
    'Ford',
    'Lexus',
    'Autre',
  ]; // Ajout de "Autre"

  // Getter pour obtenir les modèles selon la marque sélectionnée
  List<String> get _availableModels {
    if (_selectedMarques == null || _selectedMarques == 'Autre') {
      return ['Autre']; // Si "Autre" marque ou aucune marque, seulement "Autre"
    }
    return _marqueModels[_selectedMarques] ?? ['Autre'];
  }

  final List<String> _boiteVitesses = ['Manuelle', 'Automatique'];
  final List<String> _carburantsList = [
    'Essence',
    'Diesel',
    'Électrique',
    'Hybride',
  ];
  final List<String> _climatiseursList = ['Oui', 'Non'];
  final List<int> _portesList = [
    2,
    3,
    4,
    5,
  ]; // Liste d'options pour le nombre de portes

  // Liste complète des couleurs avec leurs codes
  final Map<String, Color> _couleurs = {
    'Blanc': Colors.white,
    'Noir': Colors.black,
    'Gris': Colors.grey,
    'Argenté': const Color(0xFFC0C0C0),
    'Rouge': Colors.red,
    'Bleu': Colors.blue,
    'Vert': Colors.green,
    'Jaune': Colors.yellow,
    'Orange': Colors.orange,
    'Violet': Colors.purple,
    'Rose': Colors.pink,
    'Marron': Colors.brown,
    'Beige': const Color(0xFFF5F5DC),
    'Bordeaux': const Color(0xFF800020),
    'Bleu marine': const Color(0xFF000080),
    'Vert foncé': const Color(0xFF006400),
    'Gris foncé': const Color(0xFF696969),
    'Gris clair': const Color(0xFFD3D3D3),
    'Rouge foncé': const Color(0xFF8B0000),
    'Bleu clair': const Color(0xFFADD8E6),
    'Vert clair': const Color(0xFF90EE90),
    'Jaune clair': const Color(0xFFFFFFE0),
    'Orange foncé': const Color(0xFFFF8C00),
    'Violet foncé': const Color(0xFF4B0082),
    'Rose foncé': const Color(0xFFC71585),
    'Marron clair': const Color(0xFFD2B48C),
    'Crème': const Color(0xFFFFFDD0),
    'Ivoire': const Color(0xFFFFFFF0),
    'Champagne': const Color(0xFFF7E7CE),
    'Bronze': const Color(0xFFCD7F32),
    'Doré': const Color(0xFFFFD700),
    'Cuivre': const Color(0xFFB87333),
    'Turquoise': const Color(0xFF40E0D0),
    'Cyan': const Color(0xFF00FFFF),
    'Magenta': const Color(0xFFFF00FF),
    'Lime': const Color(0xFF00FF00),
    'Indigo': const Color(0xFF4B0082),
    'Olive': const Color(0xFF808000),
    'Saumon': const Color(0xFFFA8072),
    'Corail': const Color(0xFFFF7F50),
    'Pêche': const Color(0xFFFFDAB9),
    'Lavande': const Color(0xFFE6E6FA),
    'Menthe': const Color(0xFF98FB98),
    'Bleu pétrole': const Color(0xFF008B8B),
    'Vert olive': const Color(0xFF6B8E23),
    'Rouge brique': const Color(0xFFB22222),
    'Bleu acier': const Color(0xFF4682B4),
    'Vert forêt': const Color(0xFF228B22),
    'Prune': const Color(0xFFDDA0DD),
    'Kaki': const Color(0xFFF0E68C),
    'Anthracite': const Color(0xFF36454F),
    'Perle': const Color(0xFFEAE0C8),
  };

  @override
  void initState() {
    super.initState();
    final init = widget.initialData;
    if (widget.editMode && init != null) {
      _titleController.text = (init['titre'] ?? '').toString();
      _yearController.text = (init['annee'] ?? '').toString();
      _descriptionController.text = (init['description'] ?? '').toString();
      _companyController.text = (init['entreprise'] ?? '').toString();
      _locationController.text =
          (init['lieu'] ?? init['localisation'] ?? '').toString();
      _priceController.text = (init['prix'] ?? '').toString();
      _distanceController.text = (init['distance'] ?? '').toString();
      _siegesController.text = (init['sieges'] ?? '').toString();
      _cylindreController.text = (init['cylindre'] ?? '').toString();
      _selectedBoiteVitesse = init['boiteVitesse']?.toString();
      _selectedCarburantDropdown = init['carburant']?.toString();
      _selectedClimatiseurDropdown = init['climatiseur']?.toString();
      _selectedCondition = init['condition']?.toString();
      _selectedCouleur = init['couleur']?.toString();

      final marque = init['marque']?.toString();
      if (marque != null && marque.isNotEmpty) {
        if (_marques.contains(marque)) {
          _selectedMarques = marque;
        } else {
          _selectedMarques = 'Autre';
          _customMarque = marque;
        }
      }

      final modele = init['modele']?.toString();
      if (modele != null && modele.isNotEmpty) {
        _selectedModel = modele;
      }

      final portes = init['portes'];
      final portesInt =
          portes is int ? portes : int.tryParse((portes ?? '').toString());
      if (portesInt != null) _selectedPorte = portesInt;

      if (init['photos'] is List) {
        final urls = (init['photos'] as List)
            .map((e) => e?.toString())
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toList();
        for (int i = 0; i < urls.length && i < _cloudinaryImageUrls.length; i++) {
          _cloudinaryImageUrls[i] = urls[i];
        }
      }
      if (init['video'] != null) {
        _cloudinaryVideoUrls[0] = init['video']?.toString();
      }
      _hydrateVehicleLocationFromInit(init);
    } else {
      _loadVehicleLocationFromProfile();
    }
  }

  Future<void> _loadVehicleLocationFromProfile() async {
    final profile = await SellerProfileLocations.load();
    if (!mounted || profile == null) return;
    setState(() {
      _vehicleLatitude = profile.sellerLat;
      _vehicleLongitude = profile.sellerLng;
      _vehicleAddress = profile.sellerAddress;
      _vehicleCity = profile.sellerCity;
      if (_vehicleAddress.isNotEmpty) {
        _locationController.text = _vehicleAddress;
      }
    });
  }

  String get _effectiveLieu =>
      _vehicleAddress.isNotEmpty ? _vehicleAddress : _locationController.text.trim();

  Map<String, dynamic>? get _vehicleFournisseurPayload {
    if (_vehicleLatitude == null || _vehicleLongitude == null) return null;
    return {
      'latitude': _vehicleLatitude,
      'longitude': _vehicleLongitude,
      'adresseTexte': _effectiveLieu,
    };
  }

  void _hydrateVehicleLocationFromInit(Map<String, dynamic> init) {
    _vehicleLatitude = null;
    _vehicleLongitude = null;
    _vehicleAddress = '';
    _vehicleCity = '';
    _useVehicleCurrentLocation = false;

    final f = init['fournisseur'];
    if (f is Map) {
      final m = Map<String, dynamic>.from(f);
      final lat = m['latitude'];
      final lng = m['longitude'];
      _vehicleLatitude = lat is num ? lat.toDouble() : double.tryParse('$lat');
      _vehicleLongitude = lng is num ? lng.toDouble() : double.tryParse('$lng');
      final addr = (m['adresseTexte'] ?? '').toString().trim();
      if (addr.isNotEmpty) _vehicleAddress = addr;
    }
    if (_vehicleLatitude == null || _vehicleLongitude == null) {
      final lat0 = init['latitude'];
      final lng0 = init['longitude'];
      if (lat0 != null && lng0 != null) {
        _vehicleLatitude = double.tryParse(lat0.toString());
        _vehicleLongitude = double.tryParse(lng0.toString());
      }
    }
    final lieuStr =
        (init['lieu'] ?? init['localisation'] ?? '').toString().trim();
    if (_vehicleAddress.isEmpty && lieuStr.isNotEmpty) {
      _vehicleAddress = lieuStr;
    }
    if (_vehicleAddress.isNotEmpty) {
      _locationController.text = _vehicleAddress;
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
          _vehicleCity = city?.toString() ?? '';
        });
        return address;
      }
    } catch (e) {
      log('[GEO] Reverse geocoding error: $e');
    }
    return '';
  }

  Future<void> _setVehicleLocation({
    required double lat,
    required double lng,
    required bool fromCurrent,
  }) async {
    if (!mounted) return;
    setState(() {
      _vehicleLatitude = lat;
      _vehicleLongitude = lng;
      _useVehicleCurrentLocation = fromCurrent;
      _loadingVehicleAddress = true;
    });
    final address = await _getAddressFromCoordinates(lat, lng);
    if (!mounted) return;
    setState(() {
      _vehicleAddress = address.isNotEmpty ? address : _vehicleAddress;
      if (_vehicleAddress.isNotEmpty) {
        _locationController.text = _vehicleAddress;
      }
      _loadingVehicleAddress = false;
    });
  }

  Future<void> _useCurrentVehicleLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await showDialog<void>(
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
      await _setVehicleLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        fromCurrent: true,
      );
    } catch (e) {
      log('[GEO] Erreur position actuelle véhicule: $e');
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

  Future<void> _pickImage(int startIndex) async {
    final ImagePicker picker = ImagePicker();
    // Multi-sélection sur mobile et web
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isEmpty) return;
    int gridIndex = startIndex;
    for (final img in images) {
      if (gridIndex >= _uploadedImages.length) break;
      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        setState(() {
          _uploadedImagesWeb[gridIndex] = bytes;
          _isUploadingImage[gridIndex] = true;
        });
        final url = await uploadImageToCloudinaryWeb(
          bytes,
          folder: CloudinaryFolders.vehicleImages,
        );
        if (url != null) {
          setState(() {
            _cloudinaryImageUrls[gridIndex] = url;
          });
        }
        setState(() {
          _isUploadingImage[gridIndex] = false;
        });
      } else {
        setState(() {
          _uploadedImages[gridIndex] = File(img.path);
          _isUploadingImage[gridIndex] = true;
        });
        final url = await uploadImageToCloudinary(
          _uploadedImages[gridIndex]!,
          folder: CloudinaryFolders.vehicleImages,
        );
        if (url != null) {
          setState(() {
            _cloudinaryImageUrls[gridIndex] = url;
          });
        }
        setState(() {
          _isUploadingImage[gridIndex] = false;
        });
      }
      gridIndex++;
    }
  }

  void _removeImage(int index) {
    setState(() {
      _uploadedImages[index] = null;
      _cloudinaryImageUrls[index] = null;
      _isUploadingImage[index] = false;
    });
  }

  void _removeVideo(int index) {
    setState(() {
      _uploadedVideos[index] = null;
      _cloudinaryVideoUrls[index] = null;
      _isUploadingVideo[index] = false;
      _videoUploadProgress[index] = 0.0;
    });
  }

  Future<void> _pickVideo(int index) async {
    print('[CreateSell] Début de la sélection vidéo (slot $index)');
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      print('[CreateSell] Vidéo sélectionnée: ${video.path}');

      // Vérification de la taille (500 Mo max)
      final int maxSizeBytes = 500 * 1024 * 1024; // 500 Mo
      final int videoSize = await video.length();
      final double videoSizeMB = videoSize / (1024 * 1024);
      print(
          '[CreateSell] Taille de la vidéo: ${videoSizeMB.toStringAsFixed(2)} Mo');

      if (videoSize > maxSizeBytes) {
        print(
          '[CreateSell] Vidéo trop lourde: ${videoSizeMB.toStringAsFixed(2)} Mo > 500 Mo',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La vidéo est trop lourde (${videoSizeMB.toStringAsFixed(2)} Mo). Limite: 500 Mo.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        if (!kIsWeb) {
          _uploadedVideos[index] = File(video.path);
        }
        _isUploadingVideo[index] = true;
        _videoUploadProgress[index] = 0.0;
      });
      print('[CreateSell] État mis à jour: _isUploadingVideo[$index] = true');

      try {
        String? url;
        print('[CreateSell] Plateforme: ${kIsWeb ? "Web" : "Mobile"}');

        if (kIsWeb) {
          print('[CreateSell] Lecture des bytes pour Web...');
          final bytes = await video.readAsBytes();
          print('[CreateSell] Bytes lus: ${bytes.length} bytes');
          print('[CreateSell] Appel uploadVideoToCloudinaryWeb...');
          url = await uploadVideoToCloudinaryWeb(
            bytes,
            folder: CloudinaryFolders.vehicleVideos,
          );
        } else {
          print('[CreateSell] Appel uploadVideoToCloudinary pour mobile...');
          print('[CreateSell] Fichier: ${_uploadedVideos[index]!.path}');
          url = await uploadVideoToCloudinary(
            _uploadedVideos[index]!,
            folder: CloudinaryFolders.vehicleVideos,
            onProgress: (progress) {
              setState(() {
                _videoUploadProgress[index] = progress;
              });
            },
          );
        }

        print('[CreateSell] URL retournée: $url');

        if (url != null) {
          setState(() {
            _cloudinaryVideoUrls[index] = url;
          });
          print('[CreateSell] Vidéo uploadée avec succès! URL: $url');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vidéo uploadée avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          print('[CreateSell] ERREUR: URL null retournée par Cloudinary');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Erreur lors de l\'upload de la vidéo. Veuillez réessayer.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e, stackTrace) {
        print('[CreateSell] EXCEPTION lors de l\'upload: $e');
        print('[CreateSell] Stack trace: $stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur détaillée: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      } finally {
        setState(() {
          _isUploadingVideo[index] = false;
          _videoUploadProgress[index] = 0.0;
        });
        print('[CreateSell] État final: _isUploadingVideo[$index] = false');
      }
    } else {
      print('[CreateSell] Aucune vidéo sélectionnée');
    }
  }

  bool _isSaving = false;

  bool get _isAnyUploading =>
      _isUploadingImage.contains(true) || _isUploadingVideo.contains(true);

  // Synchronisation Condition <-> Checkbox
  void _onConditionChanged(String? value) {
    setState(() {
      _selectedCondition = value;
    });
  }

  void _onValidate() {
    if (!widget.editMode) {
      _trackDemoEvent('seller_create_started', page: 'create_sell.dart');
    }
    if (widget.editMode) {
      _saveEditedCar();
      return;
    }
    // Debug logs
    print('[CreateSell] _cloudinaryVideoUrls: $_cloudinaryVideoUrls');
    print('[CreateSell] _uploadedVideos: $_uploadedVideos');

    final imagesCount = _cloudinaryImageUrls.whereType<String>().length;
    final videosCount = _cloudinaryVideoUrls.whereType<String>().length;
    final totalMedia = imagesCount + videosCount;
    if (totalMedia > _maxMediaSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vous pouvez sélectionner au maximum $_maxMediaSlots médias.',
          ),
        ),
      );
      return;
    }

    // Vérifier qu'au moins un média (image ou vidéo) est présent
    final hasImages = imagesCount > 0;
    final hasVideo = videosCount > 0;
    if (!hasImages && !hasVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez ajouter au moins une image ou une vidéo.'),
        ),
      );
      return;
    }

    if (_isAnyUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez attendre la fin de l\'upload.')),
      );
      return;
    }
    
    // Vérifie que tous les champs obligatoires sont remplis
    // Description et Dédouanement ne sont plus obligatoires
    if (_titleController.text.isEmpty ||
        _yearController.text.isEmpty ||
        _selectedCondition == null ||
        _selectedMarques == null ||
        (_selectedMarques == 'Autre' &&
            ((_customMarque == null || _customMarque!.isEmpty) ||
                (_customModel == null || _customModel!.isEmpty))) ||
        (_selectedMarques != 'Autre' &&
            (_selectedModel == null ||
                (_selectedModel == 'Autre' &&
                    (_customModel == null || _customModel!.isEmpty)))) ||
        _cylindreController.text.isEmpty ||
        _selectedPorte == null ||
        _selectedBoiteVitesse == null ||
        _selectedCarburantDropdown == null ||
        _selectedClimatiseurDropdown == null ||
        _selectedCouleur == null ||
        _distanceController.text.isEmpty ||
        _siegesController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _companyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs obligatoires.'),
        ),
      );
      return;
    }
    
    // Détermine la marque et le modèle à utiliser
    String? marque =
        _selectedMarques == 'Autre' ? _customMarque : _selectedMarques;
    String? modele;
    if (_selectedMarques == 'Autre') {
      modele = _customModel;
    } else {
      modele = _selectedModel == 'Autre' ? _customModel : _selectedModel;
    }
    
    // Passe toutes les infos à cars_info.dart
    final imagesList = _cloudinaryImageUrls.whereType<String>().toList();
    final videosList = _cloudinaryVideoUrls.whereType<String>().toList();
    print('[CreateSell] images transmises à CarsInfo: $imagesList');
    print('[CreateSell] vidéos transmises à CarsInfo: $videosList');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarsInfo(
          titre: _titleController.text,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'Description non renseignée',
          marque: marque,
          modele: modele,
          annee: _yearController.text,
          prix: _priceController.text,
          condition: _selectedCondition,
          boiteVitesse: _selectedBoiteVitesse,
          carburant: _selectedCarburantDropdown,
          climatiseur: _selectedClimatiseurDropdown,
          distance: _distanceController.text,
          sieges: _siegesController.text,
          portes: _selectedPorte?.toString(),
          cylindre: _cylindreController.text,
          couleur: _selectedCouleur,
          dedouanement: false, // Dédouanement retiré, valeur par défaut
          lieu: _effectiveLieu,
          fournisseur: _vehicleFournisseurPayload,
          images: imagesList,
          video: videosList.isNotEmpty ? videosList.first : null,
          videos: videosList,
          entreprise: _companyController.text,
          alertNotificationId: widget.alertNotificationId,
          alertBuyerId: widget.alertBuyerId,
          alertRequestType: widget.alertRequestType,
        ),
      ),
    );
  }

  Future<void> _saveEditedCar() async {
    final id = (widget.editArticleId ?? '').toString();
    if (id.isEmpty) return;

    setState(() => _isSaving = true);

    // Reuse validation (same checks)
    if (_isAnyUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez attendre la fin de l\'upload.')),
      );
      return;
    }
    if (_titleController.text.isEmpty ||
        _yearController.text.isEmpty ||
        _selectedCondition == null ||
        _selectedMarques == null ||
        (_selectedMarques == 'Autre' &&
            ((_customMarque == null || _customMarque!.isEmpty) ||
                (_customModel == null || _customModel!.isEmpty))) ||
        (_selectedMarques != 'Autre' &&
            (_selectedModel == null ||
                (_selectedModel == 'Autre' &&
                    (_customModel == null || _customModel!.isEmpty)))) ||
        _cylindreController.text.isEmpty ||
        _selectedPorte == null ||
        _selectedBoiteVitesse == null ||
        _selectedCarburantDropdown == null ||
        _selectedClimatiseurDropdown == null ||
        _selectedCouleur == null ||
        _distanceController.text.isEmpty ||
        _siegesController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _companyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires.')),
      );
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    final imagesList = _cloudinaryImageUrls.whereType<String>().toList();
    final videosList = _cloudinaryVideoUrls.whereType<String>().toList();

    String? marque = _selectedMarques == 'Autre' ? _customMarque : _selectedMarques;
    String? modele;
    if (_selectedMarques == 'Autre') {
      modele = _customModel;
    } else {
      modele = _selectedModel == 'Autre' ? _customModel : _selectedModel;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return;

      final payload = {
        'type': 'voiture',
        'titre': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'marque': marque,
        'modele': modele,
        'annee': _yearController.text.trim(),
        'prix': _priceController.text.trim(),
        'condition': _selectedCondition,
        'boiteVitesse': _selectedBoiteVitesse,
        'carburant': _selectedCarburantDropdown,
        'climatiseur': _selectedClimatiseurDropdown,
        'distance': _distanceController.text.trim(),
        'sieges': _siegesController.text.trim(),
        'portes': _selectedPorte?.toString(),
        'cylindre': _cylindreController.text.trim(),
        'couleur': _selectedCouleur,
        'photos': imagesList,
        'video': videosList.isNotEmpty ? videosList.first : null,
        'entreprise': _companyController.text.trim(),
        // compat lieu/localisation
        'lieu': _effectiveLieu,
        'localisation': _effectiveLieu,
        if (_vehicleFournisseurPayload != null)
          'fournisseur': _vehicleFournisseurPayload,
      };

      final resp = await http.put(
        Uri.parse('${UserService().dio.options.baseUrl}/articles/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildLabel(String text, {bool isRequired = true}) {
    return Text(
      isRequired ? '$text *' : text,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          isExpanded: true,
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString()),
            );
          }).toList(),
          onChanged: onChanged,
        ),
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
                    _isSaving ? 'Enregistrement...' : 'Upload en cours...',
                  ),
                ],
              )
            : Text(
                widget.editMode ? 'Sauvegarder' : 'Aperçu',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
      ),
    );
  }

  // Widget moderne pour la section images
  Widget _buildModernImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickMultipleImages(),
                icon: const Icon(Icons.add_photo_alternate, size: 20),
                label: const Text('Ajouter des images'),
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
        if (_cloudinaryImageUrls.where((url) => url != null && url!.isNotEmpty).isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_maxMediaSlots, (index) {
              final hasImage = _cloudinaryImageUrls[index] != null && _cloudinaryImageUrls[index]!.isNotEmpty;
              final isUploading = _isUploadingImage[index];
              
              if (!hasImage && !isUploading) return const SizedBox.shrink();
              
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (hasImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _cloudinaryImageUrls[index]!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.image,
                        color: Colors.grey,
                      ),
                    if (isUploading)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    if (hasImage)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
      ],
    );
  }

  // Widget pour la section vidéo
  Widget _buildVideoSection() {
    return Container(
      height: 150,
      child: PageView.builder(
        controller: _videoPageController,
        itemCount: _maxVideoSlots,
        onPageChanged: (idx) => setState(() => _currentVideoIndex = idx),
        itemBuilder: (context, index) {
          final hasVideo = _cloudinaryVideoUrls[index] != null;
          final isUploading = _isUploadingVideo[index];
          final progress = _videoUploadProgress[index];
          
          return GestureDetector(
            onTap: hasVideo
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Movie(videoUrl: _cloudinaryVideoUrls[index]!),
                      ),
                    );
                  }
                : () => _pickVideo(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasVideo ? Colors.green : Colors.blue,
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasVideo)
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
                        Text('Emplacement ${index + 1}', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        const Text('Appuyer pour ajouter', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  if (isUploading)
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
                                  value: progress > 0 ? progress : null,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                progress < 0.85 ? 'Envoi...' : 'Traitement...',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (hasVideo)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: GestureDetector(
                        onTap: () => _removeVideo(index),
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
          );
        },
      ),
    );
  }

  // Fonctions pour l'upload d'images
  Future<void> _takePhotoFromCamera() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      final emptyIndex = _cloudinaryImageUrls.indexWhere(
        (url) => url == null || url!.isEmpty,
      );
      if (emptyIndex == -1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum d\'images atteint (12 images)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      await _processImageUpload(photo, emptyIndex);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur caméra: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile>? images = await picker.pickMultiImage();
      
      if (images != null) {
        for (int i = 0; i < images.length && i < _maxMediaSlots; i++) {
          final image = images[i];
          final emptyIndex = _cloudinaryImageUrls.indexWhere((url) => url == null || url!.isEmpty);
          
          if (emptyIndex != -1 && emptyIndex < _maxMediaSlots) {
            await _processImageUpload(image, emptyIndex);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickSingleImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        final emptyIndex = _cloudinaryImageUrls.indexWhere((url) => url == null || url!.isEmpty);
        
        if (emptyIndex != -1 && emptyIndex < _maxMediaSlots) {
          await _processImageUpload(image, emptyIndex);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Maximum d\'images atteint (12 images)'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processImageUpload(XFile image, int index) async {
    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      setState(() {
        _uploadedImagesWeb[index] = bytes;
        _isUploadingImage[index] = true;
      });
      
      try {
        final url = await uploadImageToCloudinaryWeb(
          bytes,
          folder: CloudinaryFolders.vehicleImages,
        );
        if (!mounted) return;
        
        setState(() {
          _cloudinaryImageUrls[index] = url;
          _uploadedImagesWeb[index] = null;
          _isUploadingImage[index] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image ajoutée: ${image.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isUploadingImage[index] = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur upload: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      setState(() {
        _uploadedImages[index] = File(image.path);
        _isUploadingImage[index] = true;
      });
      
      try {
        final currentFile = _uploadedImages[index];
        final url = currentFile != null
            ? await uploadImageToCloudinary(
                currentFile,
                folder: CloudinaryFolders.vehicleImages,
              )
            : null;
            
        if (!mounted) return;
        
        if (url != null) {
          setState(() {
            _cloudinaryImageUrls[index] = url;
            _uploadedImages[index] = null;
            _isUploadingImage[index] = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image uploadée: ${image.name}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          setState(() => _isUploadingImage[index] = false);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isUploadingImage[index] = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur upload: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildVehicleLocationSection() {
    final hasLoc = _vehicleLatitude != null && _vehicleLongitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Localisation du véhicule', isRequired: false),
        const SizedBox(height: 8),
        const Text(
          'Reprise de votre position enregistrée à l\'inscription (profil).',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: hasLoc
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_vehicleCity.isNotEmpty)
                      Text(
                        _vehicleCity,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    Text(
                      _vehicleAddress.isNotEmpty
                          ? truncateWithEllipsis(_vehicleAddress)
                          : 'Position GPS enregistrée',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                )
              : const Text(
                  'Aucune position sur le profil — mettez à jour votre position dans Profil.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    // IMAGES EN PREMIER
                    _buildLabel('Images (max 12)', isRequired: false),
                    const SizedBox(height: 8),
                    _buildModernImageSection(),
                    const SizedBox(height: 24),
                    
                    // VIDÉO EN DEUXIÈME
                    _buildLabel('Vidéo (optionnelle, max 500 Mo)', isRequired: false),
                    const SizedBox(height: 8),
                    _buildVideoSection(),
                    const SizedBox(height: 24),
                    
                    // Nom du véhicule
                    _buildLabel('Nom du véhicule'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Entrer le nom du véhicule',
                        filled: true,
                        fillColor: const Color(0xFFF2F2F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Condition et Année
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Condition'),
                              const SizedBox(height: 8),
                              _buildDropdown<String>(
                                value: _selectedCondition,
                                hint: 'Choisissez la condition',
                                items: _conditions,
                                onChanged: _onConditionChanged,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Année'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _yearController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Entrer l\'année (ex: 2020)',
                                  filled: true,
                                  fillColor: const Color(0xFFF2F2F2),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Marque et Modèle
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Marques'),
                              const SizedBox(height: 8),
                              _buildDropdown<String>(
                                value: _selectedMarques,
                                hint: 'Choisissez la marque',
                                items: _marques,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMarques = value;
                                    if (value != 'Autre') {
                                      _customMarque = null;
                                    }
                                    _selectedModel = null;
                                    _customModel = null;
                                  });
                                },
                              ),
                              if (_selectedMarques == 'Autre')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      hintText: 'Entrez la marque',
                                      filled: true,
                                      fillColor: Color(0xFFF2F2F2),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _customMarque = val;
                                      });
                                    },
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
                              if (_selectedMarques == 'Autre')
                                TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Entrez le modèle',
                                    filled: true,
                                    fillColor: Color(0xFFF2F2F2),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _customModel = val;
                                    });
                                  },
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDropdown<String>(
                                      value: _selectedModel,
                                      hint: 'Choisissez le modèle',
                                      items: _availableModels,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedModel = value;
                                          if (value != 'Autre') _customModel = null;
                                        });
                                      },
                                    ),
                                    if (_selectedModel == 'Autre')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: TextField(
                                          decoration: const InputDecoration(
                                            hintText: 'Entrez le modèle personnalisé',
                                            filled: true,
                                            fillColor: Color(0xFFF2F2F2),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.all(Radius.circular(8)),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              _customModel = val;
                                            });
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Cylindre
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Cylindre'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _cylindreController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            ...decimalOptionalInputFormatters,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Ex: 1600 ou 1,6',
                            filled: true,
                            fillColor: const Color(0xFFF2F2F2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Couleur
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Couleur'),
                        const SizedBox(height: 8),
                        Container(
                          height: 120,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _couleurs.length,
                            itemBuilder: (context, index) {
                              final couleurNom = _couleurs.keys.elementAt(index);
                              final couleurValeur = _couleurs.values.elementAt(index);
                              final isSelected = _selectedCouleur == couleurNom;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCouleur = couleurNom;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: couleurValeur,
                                    border: Border.all(
                                      color: isSelected ? Colors.amber : Colors.grey,
                                      width: isSelected ? 3 : 1,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_selectedCouleur != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Couleur sélectionnée: $_selectedCouleur',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Porte et Boîte à vitesse
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Porte'),
                              const SizedBox(height: 8),
                              _buildDropdown<int>(
                                value: _selectedPorte,
                                hint: 'Choisissez le nombre de portes',
                                items: _portesList,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPorte = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Boîte à vitesse'),
                              const SizedBox(height: 8),
                              _buildDropdown<String>(
                                value: _selectedBoiteVitesse,
                                hint: 'Choisissez la vitesse',
                                items: _boiteVitesses,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBoiteVitesse = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Carburant et Climatiseur
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Carburant'),
                              const SizedBox(height: 8),
                              _buildDropdown<String>(
                                value: _selectedCarburantDropdown,
                                hint: 'Choisissez le carburant',
                                items: _carburantsList,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCarburantDropdown = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Climatiseur'),
                              const SizedBox(height: 8),
                              _buildDropdown<String>(
                                value: _selectedClimatiseurDropdown,
                                hint: 'Choisissez le climatiseur',
                                items: _climatiseursList,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedClimatiseurDropdown = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Kilométrage et Places
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Kilométrage'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _distanceController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  ...decimalOptionalInputFormatters,
                                  LengthLimitingTextInputFormatter(12),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Kilométrage (km), ex: 12500 ou 12,5',
                                  filled: true,
                                  fillColor: const Color(0xFFF2F2F2),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
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
                              _buildLabel('Place'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _siegesController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Nombre de places',
                                  filled: true,
                                  fillColor: const Color(0xFFF2F2F2),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Prix
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Prix'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            ...decimalOptionalInputFormatters,
                            LengthLimitingTextInputFormatter(14),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Prix en FCFA (ex: 1500000 ou 1.500.000,5)',
                            filled: true,
                            fillColor: const Color(0xFFF2F2F2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Description (optionnelle)
                    _buildLabel('Description', isRequired: false),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Entrer une description de votre voiture (optionnel)',
                        filled: true,
                        fillColor: const Color(0xFFF2F2F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nom de l'entreprise
                    _buildLabel('Nom de l\'entreprise possédant le BL'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _companyController,
                      decoration: InputDecoration(
                        hintText: 'Entrer le nom de l\'entreprise',
                        filled: true,
                        fillColor: const Color(0xFFF2F2F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildVehicleLocationSection(),
                    ],
                ),
              ),
            ),
            _buildVerificationButton(context),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _cylindreController.dispose();
    _distanceController.dispose();
    _siegesController.dispose();
    _priceController.dispose();
    _videoPageController.dispose();
    super.dispose();
  }
}

// Fonction d'upload Cloudinary pour Flutter Web
Future<String?> uploadImageToCloudinaryWeb(
  Uint8List bytes, {
  String folder = CloudinaryFolders.vehicleImages,
}) async {
  // Remplace par ta clé Cloudinary et ton preset
  const String cloudName = 'dy0raj5bh'; // <-- à remplacer par ton cloud name
  const String uploadPreset =
      'unsigned_preset'; // <-- à remplacer par ton preset
  final url = Uri.parse(
    'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
  );

  final request = http.MultipartRequest('POST', url)
    ..fields['upload_preset'] = uploadPreset
    ..fields['folder'] = folder
    ..files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: 'upload.jpg'),
    );

  final response = await request.send();
  if (response.statusCode == 200) {
    final respStr = await response.stream.bytesToString();
    final json = jsonDecode(respStr) as Map<String, dynamic>;
    return json['secure_url'] as String?;
  } else {
    return null;
  }
}

// Fonction d'upload vidéo pour Web
Future<String?> uploadVideoToCloudinaryWeb(
  Uint8List bytes, {
  String folder = CloudinaryFolders.vehicleVideos,
}) async {
  const String cloudName = 'dy0raj5bh';
  const String uploadPreset = 'unsigned_preset';
  final url = Uri.parse(
    'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
  );

  final request = http.MultipartRequest('POST', url)
    ..fields['upload_preset'] = uploadPreset
    ..fields['folder'] = folder
    ..files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: 'video.mp4'),
    );

  final response = await request.send();
  if (response.statusCode == 200) {
    final respStr = await response.stream.bytesToString();
    final json = jsonDecode(respStr) as Map<String, dynamic>;
    return json['secure_url'] as String?;
  } else {
    return null;
  }
}