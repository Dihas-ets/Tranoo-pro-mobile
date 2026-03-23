import 'package:flutter/material.dart';
import 'package:tranoo_pro/services/push_otp_service.dart';
import 'package:tranoo_pro/widgets/auth_message_popup.dart';

class CreateNewPasswordPage extends StatefulWidget {
  final String requestId;
  final String deviceId;

  const CreateNewPasswordPage({
    super.key,
    required this.requestId,
    required this.deviceId,
  });

  @override
  State<CreateNewPasswordPage> createState() => _CreateNewPasswordPageState();
}

class _CreateNewPasswordPageState extends State<CreateNewPasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Critères de validation du mot de passe
  bool _hasDigit = false;
  bool _hasLowercase = false;
  bool _hasUppercase = false;
  bool _hasSpecialChar = false;
  bool _hasValidLength = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_updatePasswordStrength);
    
    // Initialiser les animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _newPasswordController.text;

    setState(() {
      _hasDigit = RegExp(r'[0-9]').hasMatch(password);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(password);
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      _hasSpecialChar = RegExp(r'[!@#&()]').hasMatch(password);
      _hasValidLength = password.length >= 8 && password.length <= 20;
    });
  }

  bool get _isPasswordValid {
    return _hasDigit &&
        _hasLowercase &&
        _hasUppercase &&
        _hasSpecialChar &&
        _hasValidLength;
  }

  Future<void> _createNewPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isPasswordValid) {
      AuthMessagePopup.showError(
        context,
        title: 'Mot de passe trop faible.',
        subtitle: 'Vérifiez les critères affichés et réessayez.',
        buttonText: 'OK',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await PushOTPService.resetPassword(
        requestId: widget.requestId,
        deviceId: widget.deviceId,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        // Animation de succès
        _animationController.reverse().then((_) {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
        
        AuthMessagePopup.showSuccess(
          context,
          title: result['message']?.toString() ?? 'Mot de passe modifié avec succès.',
        );
      } else {
        AuthMessagePopup.showError(
          context,
          title: result['message']?.toString() ?? 'Une erreur est survenue.',
          buttonText: 'Réessayer',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AuthMessagePopup.showError(
        context,
        title: 'Une erreur est survenue.',
        subtitle: 'Vérifiez votre connexion et réessayez.',
        buttonText: 'Réessayer',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un nouveau mot de passe'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF9FAFB),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header avec icône animée
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8BF13).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_reset,
                            size: 48,
                            color: Color(0xFFF8BF13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Titre principal
                      const Center(
                        child: Text(
                          'Créez un nouveau mot de passe',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Entrez et confirmez votre nouveau mot de passe',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),

              // Nouveau mot de passe
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(
                        () => _obscureNewPassword = !_obscureNewPassword,
                      );
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un mot de passe';
                  }
                  if (!_isPasswordValid) {
                    return 'Le mot de passe ne respecte pas tous les critères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirmer mot de passe
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirmer mot de passe',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      );
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez confirmer le mot de passe';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Critères de validation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Votre mot de passe doit contenir:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCriterion('au moins un chiffre [0-9]', _hasDigit),
                    _buildCriterion(
                      'au moins un caractère minuscule [a-z]',
                      _hasLowercase,
                    ),
                    _buildCriterion(
                      'au moins un caractère majuscule [A-Z]',
                      _hasUppercase,
                    ),
                    _buildCriterion(
                      'au moins un caractère spécial comme !@#& ()',
                      _hasSpecialChar,
                    ),
                    _buildCriterion(
                      'au minimum 8 caractères et au maximum 20 caractères',
                      _hasValidLength,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Bouton Enregistrer
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createNewPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8BF13), // Jaune de l'app
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child:
                      _loading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                          : const Text(
                            'Enregistrer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCriterion(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isValid ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isValid ? Colors.green.shade700 : Colors.grey.shade600,
                fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
