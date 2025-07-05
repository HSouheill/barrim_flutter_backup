import 'package:flutter/material.dart';
import '../models/service_provider.dart';
import '../services/service_provider_services.dart';

class ServiceProviderController extends ChangeNotifier {
  final ServiceProviderService _service = ServiceProviderService();

  ServiceProvider? _serviceProvider;
  bool _isLoading = true;
  String? _error;

  ServiceProvider? get serviceProvider => _serviceProvider;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize and fetch data
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _serviceProvider = await _service.getServiceProviderData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh data (can be called when needed)
  Future<void> refreshData() async {
    await initialize();
  }
}