import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/wholesaler_model.dart';
import '../../../../services/wholesaler_service.dart';
import '../../../../services/api_service.dart';
import '../../headers/wholesaler_header.dart';


class WholesalerPersonalInformation extends StatefulWidget {
  const WholesalerPersonalInformation({Key? key}) : super(key: key);

  @override
  State<WholesalerPersonalInformation> createState() => _WholesalerPersonalInformationState();
}

class _WholesalerPersonalInformationState extends State<WholesalerPersonalInformation> {
  final WholesalerService _wholesalerService = WholesalerService();

  // Business information
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _subCategoryController = TextEditingController();

  // Contact information
  final TextEditingController _websiteController = TextEditingController();


  bool _isLoading = true;
  bool _isSaving = false;
  Wholesaler? _wholesalerData;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _loadWholesalerData();
  }

  Future<void> _loadWholesalerData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final wholesaler = await _wholesalerService.getWholesalerData();

      if (wholesaler != null) {
        setState(() {
          _wholesalerData = wholesaler;

          // Set business information
          _businessNameController.text = wholesaler.businessName;
          _phoneController.text = wholesaler.phone;
          _categoryController.text = wholesaler.category;
          _subCategoryController.text = wholesaler.subCategory ?? '';

          // Set contact information
          _websiteController.text = wholesaler.contactInfo.website;

        });

        // Load logo URL
        _loadLogoUrl(wholesaler.logoUrl);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLogoUrl(String? logoUrl) async {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      // Convert logo URL to full URL if it's a relative path
      String? processedLogoUrl = logoUrl;
      
      // If it starts with file://, remove it and convert to full URL
      if (processedLogoUrl.startsWith('file://')) {
        processedLogoUrl = processedLogoUrl.replaceFirst('file://', '');
        // Remove leading slash if present
        if (processedLogoUrl.startsWith('/')) {
          processedLogoUrl = processedLogoUrl.substring(1);
        }
        processedLogoUrl = '${ApiService.baseUrl}/$processedLogoUrl';
      }
      // If it's a relative path, convert to full URL
      else if (processedLogoUrl.startsWith('/') || processedLogoUrl.startsWith('uploads/')) {
        processedLogoUrl = '${ApiService.baseUrl}/$processedLogoUrl';
      }
      
      setState(() {
        _logoUrl = processedLogoUrl;
      });
    }
  }

  Future<void> _saveWholesalerData() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Create updated data map based on the actual model structure
      final updatedData = {
        'businessName': _businessNameController.text,
        'phone': _phoneController.text,
        'category': _categoryController.text,
        'subCategory': _subCategoryController.text.isEmpty ? null : _subCategoryController.text,

        'contactInfo': {
          'website': _websiteController.text,
        },
      };

      final success = await _wholesalerService.updateWholesalerData(updatedData);

      if (success) {
        _showSuccessSnackBar('Wholesaler information updated successfully');
      } else {
        _showErrorSnackBar('Failed to update wholesaler information');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating information: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: Colors.green,
    //   ),
    // );
  }

  void _showErrorSnackBar(String message) {
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: Colors.red,
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          WholesalerHeader(logoUrl: _logoUrl),
          Expanded(
            child: Container(
              color: Colors.white,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Color(0xFF2079C2)))
                  : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBackButton(),
                      const SizedBox(height: 8),
                      _buildTitle(),
                      const SizedBox(height: 16),
                      _buildForm(),
                      const SizedBox(height: 20),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () => Navigator.of(context).pop(),
      child: Row(
        children: [
          Icon(Icons.arrow_back, color: Color(0xFF2079C2)),
          const SizedBox(width: 8),
          Text(
            'Personal Information',
            style: TextStyle(
              color: Color(0xFF2079C2),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Wholesaler Information',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Business Information'),
        _buildLabel('Business Name'),
        _buildTextField(_businessNameController),
        const SizedBox(height: 16),

        _buildLabel('Phone Number'),
        _buildTextField(_phoneController, keyboardType: TextInputType.phone),
        const SizedBox(height: 16),

        _buildTwoColumnFields(
          firstLabel: 'Category',
          firstController: _categoryController,
          secondLabel: 'Sub-Category',
          secondController: _subCategoryController,
        ),
        const SizedBox(height: 24),

        _buildSectionTitle('Contact Information'),
        _buildLabel('Website'),
        _buildTextField(_websiteController, keyboardType: TextInputType.url),
        const SizedBox(height: 16),



      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2079C2),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, {
        TextInputType keyboardType = TextInputType.text,
        bool readOnly = false,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTwoColumnFields({
    required String firstLabel,
    required TextEditingController firstController,
    required String secondLabel,
    required TextEditingController secondController,
    bool firstReadOnly = false,
    bool secondReadOnly = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(firstLabel),
              _buildTextField(firstController, readOnly: firstReadOnly),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(secondLabel),
              _buildTextField(secondController, readOnly: secondReadOnly),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveWholesalerData,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF2079C2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isSaving
            ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          'Save',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}