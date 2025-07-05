import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SocialLinksEditor extends StatefulWidget {
  // Initial values for social links
  final String initialWebsite;
  final String initialFacebook;
  final String initialInstagram;

  final Function? onUpdateSuccess;

  const SocialLinksEditor({
    Key? key,
    this.initialWebsite = '',
    this.initialFacebook = '',
    this.initialInstagram = '',
    this.onUpdateSuccess,
  }) : super(key: key);

  @override
  State<SocialLinksEditor> createState() => _SocialLinksEditorState();
}

class _SocialLinksEditorState extends State<SocialLinksEditor> {
  late TextEditingController _websiteController;
  late TextEditingController _facebookController;
  late TextEditingController _instagramController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _websiteController = TextEditingController(text: widget.initialWebsite);
    _facebookController = TextEditingController(text: widget.initialFacebook);
    _instagramController = TextEditingController(text: widget.initialInstagram);

  }

  @override
  void dispose() {
    _websiteController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();

    super.dispose();
  }

  Future<void> _updateSocialLinks() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.updateServiceProviderSocialLinks(
      website: _websiteController.text.trim(),
      facebook: _facebookController.text.trim(),
      instagram: _instagramController.text.trim(),

    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text("Social links updated successfully"),
      //     backgroundColor: Colors.green,
      //   ),
      // );

      // Call callback if provided
      if (widget.onUpdateSuccess != null) {
        widget.onUpdateSuccess!();
      }

      Navigator.pop(context);
    } else {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text("Failed to update social links. Please try again."),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Social Links',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _websiteController,
                labelText: 'Website',
                hintText: 'https://www.example.com',
                icon: Icons.language,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _facebookController,
                labelText: 'Facebook',
                hintText: 'https://facebook.com/yourpage',
                icon: Icons.facebook,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _instagramController,
                labelText: 'Instagram',
                hintText: '@username or URL',
                icon: Icons.camera_alt,
              ),
            
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateSocialLinks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066B3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
    );
  }
}