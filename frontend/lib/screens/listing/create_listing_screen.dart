import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../../utils/validators.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pickupLocationController = TextEditingController();

  String _selectedCategory = 'Restaurant';
  String _selectedUnit = 'portions';
  final List<String> _selectedDietaryTags = [];
  final List<File> _selectedImages = [];
  DateTime _pickupStart = DateTime.now().add(const Duration(hours: 1));
  DateTime _pickupEnd = DateTime.now().add(const Duration(hours: 4));
  DateTime? _expiryDate;
  GeoPoint? _location;
  bool _isSubmitting = false;
  bool _isLocating = false;

  final _imagePicker = ImagePicker();
  final _storageService = StorageService();
  late final LocationService _locationService =
      ref.read(locationServiceProvider);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _originalPriceController.dispose();
    _discountedPriceController.dispose();
    _quantityController.dispose();
    _phoneController.dispose();
    _pickupLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (images.length + _selectedImages.length > AppConstants.maxImagesPerListing) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 images allowed'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() {
      _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
    });
  }

  /// Captures the provider's current position. A listing without a real
/// coordinate cannot be matched to nearby buyers, so this is required rather
/// than falling back to 0,0.
Future<void> _useCurrentLocation() async {
  if (_isLocating) return;
  setState(() => _isLocating = true);
  try {
    final point = await _locationService.getCurrentGeoPoint();
    if (!mounted) return;
    if (isNullIsland(point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not get your location. Enable location access and try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final address = await _locationService.getAddressFromGeoPoint(point!);
    if (!mounted) return;
    setState(() {
      _location = point;
      if (address != null && _pickupLocationController.text.trim().isEmpty) {
        _pickupLocationController.text = address;
      }
    });
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not get your location: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  } finally {
    if (mounted) setState(() => _isLocating = false);
  }
}

Future<void> _selectPickupTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _pickupStart : _pickupEnd,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          isStart ? _pickupStart : _pickupEnd,
        ),
      );
      if (time != null) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        setState(() {
          if (isStart) {
            _pickupStart = dateTime;
            if (_pickupEnd.isBefore(_pickupStart.add(const Duration(hours: 1)))) {
              _pickupEnd = _pickupStart.add(const Duration(hours: 1));
            }
          } else {
            _pickupEnd = dateTime;
          }
        });
      }
    }
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: 23, minute: 59),
      );
      setState(() {
        _expiryDate = DateTime(
          date.year,
          date.month,
          date.day,
          time?.hour ?? 23,
          time?.minute ?? 59,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one food image'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_pickupEnd.isBefore(_pickupStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup end time must be after start time'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set an expiry date'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (isNullIsland(_location)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your pickup location'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final originalPrice = double.parse(_originalPriceController.text.trim());
    final discountedPrice =
        double.parse(_discountedPriceController.text.trim());
    if (discountedPrice > originalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your price cannot be higher than the original price'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final imageUrls = await _storageService.uploadImages(
        _selectedImages,
        'listings/${user.id}',
      );

      final listing = {
        'providerId': user.id,
        'providerName': user.businessName ?? user.name,
        'providerPhone': _phoneController.text.trim(),
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'originalPrice': originalPrice,
        'discountedPrice': discountedPrice,
        'quantity': int.parse(_quantityController.text.trim()),
        'unit': _selectedUnit,
        'images': imageUrls,
        'location': _location!,
        'pickupLocation': _pickupLocationController.text.trim(),
        'pickupStart': Timestamp.fromDate(_pickupStart),
        'pickupEnd': Timestamp.fromDate(_pickupEnd),
        'expiryDate': Timestamp.fromDate(_expiryDate!),
        'status': 'available',
        'dietaryTags': _selectedDietaryTags,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('listings').add(listing);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Listing'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(),
              const SizedBox(height: 24),
              _buildFoodDetails(),
              const SizedBox(height: 24),
              _buildPricingSection(),
              const SizedBox(height: 24),
              _buildContactSection(),
              const SizedBox(height: 24),
              _buildPickupSection(),
              const SizedBox(height: 24),
              _buildExpirySection(),
              const SizedBox(height: 24),
              _buildDietarySection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Food Images',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._selectedImages.asMap().entries.map((entry) {
                return Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(entry.value),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImages.removeAt(entry.key);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_selectedImages.length < AppConstants.maxImagesPerListing)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.divider,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: AppColors.textHint),
                        SizedBox(height: 4),
                        Text('Add', style: TextStyle(color: AppColors.textHint)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Food Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _titleController,
          validator: (v) => Validators.required(v, 'Title'),
          decoration: const InputDecoration(labelText: 'Food Title'),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          validator: Validators.description,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description',
            alignLabelWithHint: true,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items: AppConstants.categories
              .where((c) => c != 'All')
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _quantityController,
                validator: Validators.quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedUnit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: AppConstants.units
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedUnit = v!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pricing',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _originalPriceController,
                validator: Validators.price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Original Price',
                  prefixText: '₹',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _discountedPriceController,
                validator: Validators.price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Your Price',
                  prefixText: '₹',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Contact & Pickup Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          validator: (v) => Validators.required(v, 'Phone number'),
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Contact Phone Number',
            prefixIcon: Icon(Icons.phone_outlined),
            prefixText: '+91 ',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Buyers will use this to coordinate pickup via OTP verification',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _pickupLocationController,
          validator: (v) => Validators.required(v, 'Pickup location'),
          decoration: const InputDecoration(
            labelText: 'Pickup Location / Landmark',
            prefixIcon: Icon(Icons.location_on_outlined),
            hintText: 'e.g., Main entrance, Near parking lot',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 4),
        Text(
          'Specific instructions for where buyers should pick up the food',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isSubmitting || _isLocating ? null : _useCurrentLocation,
          icon: _isLocating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location, size: 18),
          label: Text(
            _location == null
                ? 'Use my current location'
                : 'Location captured - tap to update',
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupSection() {
    final dateFormat = DateFormat('MMM d, h:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Pickup Window',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPickupButton(
                'From',
                dateFormat.format(_pickupStart),
                () => _selectPickupTime(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPickupButton(
                'Until',
                dateFormat.format(_pickupEnd),
                () => _selectPickupTime(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPickupButton(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpirySection() {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Best Before / Expiry',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'When should this food be consumed by?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _selectExpiryDate,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: _expiryDate != null
                    ? AppColors.primary
                    : AppColors.divider,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  color: _expiryDate != null
                      ? AppColors.primary
                      : AppColors.textHint,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _expiryDate != null
                      ? dateFormat.format(_expiryDate!)
                      : 'Select expiry date & time',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _expiryDate != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                ),
                const Spacer(),
                if (_expiryDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _expiryDate = null),
                    child: const Icon(Icons.close,
                        size: 18, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDietarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dietary Tags',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: AppConstants.dietaryTags.map((tag) {
            final isSelected = _selectedDietaryTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDietaryTags.add(tag);
                  } else {
                    _selectedDietaryTags.remove(tag);
                  }
                });
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    );
  }
}
