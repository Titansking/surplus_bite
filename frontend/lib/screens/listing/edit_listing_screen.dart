import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../utils/validators.dart';

class EditListingScreen extends ConsumerStatefulWidget {
  const EditListingScreen({super.key});

  @override
  ConsumerState<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends ConsumerState<EditListingScreen> {
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
  List<String> _selectedDietaryTags = [];
  DateTime? _pickupStart;
  DateTime? _pickupEnd;
  DateTime? _expiryDate;
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _listingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadListing();
    });
  }

  Future<void> _loadListing() async {
    final listingId =
        ModalRoute.of(context)!.settings.arguments as String;
    _listingId = listingId;

    final doc =
        await FirebaseFirestore.instance.collection('listings').doc(listingId).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _originalPriceController.text =
            (data['originalPrice'] ?? 0).toString();
        _discountedPriceController.text =
            (data['discountedPrice'] ?? 0).toString();
        _quantityController.text = (data['quantity'] ?? 0).toString();
        _selectedCategory = data['category'] ?? 'Restaurant';
        _selectedUnit = data['unit'] ?? 'portions';
        _selectedDietaryTags =
            List<String>.from(data['dietaryTags'] ?? []);
        _phoneController.text = data['providerPhone'] ?? '';
        _pickupLocationController.text = data['pickupLocation'] ?? '';
        _pickupStart =
            (data['pickupStart'] as Timestamp?)?.toDate();
        _pickupEnd = (data['pickupEnd'] as Timestamp?)?.toDate();
        _expiryDate = (data['expiryDate'] as Timestamp?)?.toDate();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectPickupTime(bool isStart) async {
    final current = isStart ? _pickupStart : _pickupEnd;
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current ?? DateTime.now()),
      );
      if (time != null) {
        final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        setState(() {
          if (isStart) {
            _pickupStart = dateTime;
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
    if (!_formKey.currentState!.validate() || _listingId == null) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set an expiry date'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final updates = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'originalPrice': double.parse(_originalPriceController.text),
        'discountedPrice': double.parse(_discountedPriceController.text),
        'quantity': int.parse(_quantityController.text),
        'unit': _selectedUnit,
        'providerPhone': _phoneController.text.trim(),
        'pickupLocation': _pickupLocationController.text.trim(),
        'dietaryTags': _selectedDietaryTags,
        'updatedAt': Timestamp.now(),
      };

      if (_pickupStart != null) {
        updates['pickupStart'] = Timestamp.fromDate(_pickupStart!);
      }
      if (_pickupEnd != null) {
        updates['pickupEnd'] = Timestamp.fromDate(_pickupEnd!);
      }
      updates['expiryDate'] = Timestamp.fromDate(_expiryDate!);

      await FirebaseFirestore.instance
          .collection('listings')
          .doc(_listingId)
          .update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing updated!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Listing')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Listing'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                validator: (v) => Validators.required(v, 'Title'),
                decoration: const InputDecoration(labelText: 'Food Title'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                validator: Validators.description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: AppConstants.categories.where((c) => c != 'All').map(
                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                ).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
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
                        labelText: 'Original Price', prefixText: '₹',
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
                        labelText: 'Your Price', prefixText: '₹',
                      ),
                    ),
                  ),
                ],
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
                      value: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: AppConstants.units.map(
                        (u) => DropdownMenuItem(value: u, child: Text(u)),
                      ).toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v!),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _pickupLocationController,
                validator: (v) => Validators.required(v, 'Pickup location'),
                decoration: const InputDecoration(
                  labelText: 'Pickup Location / Landmark',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeButton('From', _pickupStart, () => _selectPickupTime(true)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTimeButton('Until', _pickupEnd, () => _selectPickupTime(false)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _selectExpiryDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _expiryDate != null ? AppColors.primary : AppColors.divider,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            color: _expiryDate != null ? AppColors.primary : AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _expiryDate != null
                                ? 'Best before: ${DateFormat('MMM d, yyyy • h:mm a').format(_expiryDate!)}'
                                : 'Set expiry date (required)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _expiryDate != null ? AppColors.textPrimary : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: AppConstants.dietaryTags.map((tag) {
                    final sel = _selectedDietaryTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: sel,
                      onSelected: (s) {
                        setState(() {
                          if (s) _selectedDietaryTags.add(tag);
                          else _selectedDietaryTags.remove(tag);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeButton(String label, DateTime? value, VoidCallback onTap) {
    final fmt = DateFormat('MMM d, h:mm a');
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
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              value != null ? fmt.format(value) : 'Select time',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
