import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TypeVendeurMigrationDialog extends StatefulWidget {
  final Function(String) onTypeSelected;

  const TypeVendeurMigrationDialog({
    Key? key,
    required this.onTypeSelected,
  }) : super(key: key);

  @override
  State<TypeVendeurMigrationDialog> createState() => _TypeVendeurMigrationDialogState();
}

class _TypeVendeurMigrationDialogState extends State<TypeVendeurMigrationDialog> {
  String _selectedType = 'mixte'; // mixte | vehicules | pieces
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8BF13).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.category,
                    color: Color(0xFFF8BF13),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Mise à jour Tranoo Pro",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "Nouvelles fonctionnalités vendeurs",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Message explicatif
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Tranoo Pro évolue ! Précisez ce que vous vendez pour une expérience optimisée.",
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Options
            Text(
              "Que souhaitez-vous vendre principalement ?",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Radio buttons
            _buildRadioOption(
              'mixte',
              "Vendeur mixte",
              "Je vends des véhicules ET des pièces détachées",
              Icons.category,
              true, // Recommandé
            ),
            
            _buildRadioOption(
              'vehicules',
              "Vendeur de véhicules",
              "Je vends uniquement des véhicules",
              Icons.directions_car,
              false,
            ),
            
            _buildRadioOption(
              'pieces',
              "Vendeur de pièces",
              "Je vends uniquement des pièces détachées",
              Icons.build,
              false,
            ),
            
            const SizedBox(height: 24),
            
            // Boutons d'action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _confirmSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8BF13),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text("Enregistrer mon choix"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String type, String title, String description, IconData icon, bool isRecommended) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RadioListTile<String>(
        value: type,
        groupValue: _selectedType,
        onChanged: (value) {
          setState(() {
            _selectedType = value!;
          });
        },
        title: Row(
          children: [
            Icon(
              icon,
              color: _selectedType == type ? const Color(0xFFF8BF13) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _selectedType == type ? const Color(0xFFF8BF13) : Colors.black,
                ),
              ),
            ),
            if (isRecommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Recommandé",
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            description,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        activeColor: const Color(0xFFF8BF13),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _confirmSelection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken();
        final resp = await http.patch(
          Uri.parse('${getBaseUrl()}/users/me'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'vendeurType': _selectedType}),
        );
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw Exception('Erreur mise à jour (${resp.statusCode})');
        }

        UserService().setVendeurType(_selectedType);
        widget.onTypeSelected(_selectedType);
        Navigator.of(context).pop();
        
        // Message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Préférence enregistrée avec succès !"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'enregistrement: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
