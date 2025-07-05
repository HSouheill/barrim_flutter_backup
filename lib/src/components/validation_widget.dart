import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/validation_service.dart';

class ValidationWidget extends StatefulWidget {
  final TextEditingController controller;
  final String fieldType; // 'email', 'password', 'phone'
  final String? userType; // For context-specific validation
  final Function(bool isValid) onValidationChanged;
  final bool showRealTimeValidation;
  final String? labelText;
  final String? hintText;
  final bool isPassword;
  final bool isRequired;

  const ValidationWidget({
    Key? key,
    required this.controller,
    required this.fieldType,
    this.userType,
    required this.onValidationChanged,
    this.showRealTimeValidation = true,
    this.labelText,
    this.hintText,
    this.isPassword = false,
    this.isRequired = true,
  }) : super(key: key);

  @override
  State<ValidationWidget> createState() => _ValidationWidgetState();
}

class _ValidationWidgetState extends State<ValidationWidget> {
  bool _isValidating = false;
  bool _isValid = false;
  String? _errorMessage;
  String? _warningMessage;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFieldChanged);
    super.dispose();
  }

  void _onFieldChanged() {
    if (widget.showRealTimeValidation) {
      _validateField();
    }
  }

  Future<void> _validateField() async {
    final value = widget.controller.text.trim();
    
    // Don't validate empty fields unless required
    if (value.isEmpty) {
      if (widget.isRequired) {
        setState(() {
          _isValid = false;
          _errorMessage = 'This field is required';
          _warningMessage = null;
        });
        widget.onValidationChanged(false);
      } else {
        setState(() {
          _isValid = true;
          _errorMessage = null;
          _warningMessage = null;
        });
        widget.onValidationChanged(true);
      }
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _warningMessage = null;
    });

    try {
      switch (widget.fieldType) {
        case 'email':
          await _validateEmail(value);
          break;
        case 'password':
          _validatePassword(value);
          break;
        case 'phone':
          await _validatePhone(value);
          break;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Validation error: ${e.toString()}';
        _isValid = false;
      });
      widget.onValidationChanged(false);
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> _validateEmail(String email) async {
    // First check format
    if (!ValidationService.isValidEmail(email)) {
      setState(() {
        _isValid = false;
        _errorMessage = 'Please enter a valid email address';
      });
      widget.onValidationChanged(false);
      return;
    }

    // Then check if it exists
    try {
      final result = await ValidationService.checkEmailExists(email);
      if (result['exists']) {
        List<String> existingTypes = result['userTypes'];
        setState(() {
          _isValid = false;
          _errorMessage = 'Email already exists for: ${existingTypes.join(', ')}';
        });
        widget.onValidationChanged(false);
      } else {
        setState(() {
          _isValid = true;
          _errorMessage = null;
        });
        widget.onValidationChanged(true);
      }
    } catch (e) {
      setState(() {
        _isValid = true; // Assume valid if we can't check
        _warningMessage = 'Could not verify email availability';
      });
      widget.onValidationChanged(true);
    }
  }

  void _validatePassword(String password) {
    final validation = ValidationService.validatePassword(password);
    if (validation['isValid']) {
      setState(() {
        _isValid = true;
        _errorMessage = null;
      });
      widget.onValidationChanged(true);
    } else {
      setState(() {
        _isValid = false;
        _errorMessage = validation['errors'].first; // Show first error
      });
      widget.onValidationChanged(false);
    }
  }

  Future<void> _validatePhone(String phone) async {
    // First check format
    if (!ValidationService.isValidPhone(phone)) {
      setState(() {
        _isValid = false;
        _errorMessage = 'Please enter a valid phone number';
      });
      widget.onValidationChanged(false);
      return;
    }

    // Then check if it exists
    try {
      final result = await ValidationService.checkPhoneExists(phone);
      if (result['exists']) {
        List<String> existingTypes = result['userTypes'];
        setState(() {
          _isValid = false;
          _errorMessage = 'Phone number already exists for: ${existingTypes.join(', ')}';
        });
        widget.onValidationChanged(false);
      } else {
        setState(() {
          _isValid = true;
          _errorMessage = null;
        });
        widget.onValidationChanged(true);
      }
    } catch (e) {
      setState(() {
        _isValid = true; // Assume valid if we can't check
        _warningMessage = 'Could not verify phone availability';
      });
      widget.onValidationChanged(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword && !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: widget.labelText ?? _getDefaultLabel(),
            hintText: widget.hintText,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  )
                : _isValidating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : _isValid
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          )
                        : null,
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white,
                width: 2.0,
                style: BorderStyle.solid,
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white,
                width: 2.0,
                style: BorderStyle.solid,
              ),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.red,
                width: 2.0,
                style: BorderStyle.solid,
              ),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.red,
                width: 2.0,
                style: BorderStyle.solid,
              ),
            ),
            labelStyle: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 16,
            ),
            hintStyle: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 16,
          ),
          validator: (value) {
            if (widget.isRequired && (value == null || value.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _errorMessage!,
              style: GoogleFonts.nunito(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        if (_warningMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _warningMessage!,
              style: GoogleFonts.nunito(
                color: Colors.orange,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  String _getDefaultLabel() {
    switch (widget.fieldType) {
      case 'email':
        return 'Email address';
      case 'password':
        return 'Password';
      case 'phone':
        return 'Phone number';
      default:
        return 'Field';
    }
  }
} 