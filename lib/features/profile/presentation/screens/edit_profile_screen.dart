import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/avatar_circle.dart';

String _ageLabel(int? age, String? legacyRange) {
  if (age != null) return '$age years';
  return switch (legacyRange) {
    '18_24' => '18–24',
    '25_34' => '25–34',
    '35_44' => '35–44',
    '45_54' => '45–54',
    '55_plus' => '55+',
    _ => 'Not provided',
  };
}

String _genderLabel(String? value) => switch (value) {
      'woman' => 'Woman',
      'man' => 'Man',
      'non_binary' => 'Non-binary',
      'prefer_not_to_say' => 'Prefer not to say',
      _ => 'Not provided',
    };

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _localAvatarUrl;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _businessCtrl.dispose();
    _locationCtrl.dispose();
    _websiteCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 90, maxWidth: 1600);
      if (file == null || !mounted) return;
      final viewport = MediaQuery.sizeOf(context);
      final safePadding = MediaQuery.paddingOf(context).vertical;
      final availableWidth = (viewport.width - 48).clamp(160.0, 300.0);
      final availableHeight =
          (viewport.height - safePadding - 260).clamp(160.0, 300.0);
      final cropSize = math.min(availableWidth, availableHeight).round();
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        maxWidth: 800,
        maxHeight: 800,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop profile photo',
            lockAspectRatio: false,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: const [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.original,
            ],
          ),
          IOSUiSettings(
            title: 'Crop profile photo',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            rotateButtonsHidden: false,
            aspectRatioPickerButtonHidden: false,
            aspectRatioPresets: const [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.original,
            ],
          ),
          WebUiSettings(
            context: context,
            size: CropperSize(width: cropSize, height: cropSize),
            viewwMode: WebViewMode.mode_1,
            dragMode: WebDragMode.move,
            cropBoxMovable: true,
            cropBoxResizable: true,
            rotatable: true,
            scalable: true,
            zoomable: true,
            zoomOnTouch: true,
          ),
        ],
      );
      if (cropped == null) return;
      if (!mounted) return;
      final editedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) =>
              _AvatarAdjustScreen(imageBytes: cropped.readAsBytes()),
        ),
      );
      if (editedBytes == null || !mounted) return;
      if (mounted) setState(() => _uploadingPhoto = true);
      final url = await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(editedBytes, 'png');
      if (mounted) {
        setState(() => _localAvatarUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto(String? avatarPath) async {
    setState(() => _uploadingPhoto = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .removeAvatar(avatarPath: avatarPath);
      if (mounted) {
        setState(() => _localAvatarUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo removed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            displayName: name,
            professionalTitle: _titleCtrl.text.trim(),
            businessName: _businessCtrl.text.trim(),
            location: _locationCtrl.text.trim(),
            website: _websiteCtrl.text.trim(),
            country: _countryCtrl.text.trim(),
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.save(e).message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final email = ref.watch(authRepositoryProvider).currentUserEmail;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text(Failure.from(e).message)),
        data: (profile) {
          if (profile == null) return const LoadingIndicator();
          if (!_initialized) {
            _nameCtrl.text = profile.displayName;
            _titleCtrl.text = profile.professionalTitle ?? '';
            _businessCtrl.text = profile.businessName ?? '';
            _locationCtrl.text = profile.location ?? '';
            _websiteCtrl.text = profile.website ?? '';
            _countryCtrl.text = profile.country ?? '';
            _localAvatarUrl = profile.avatarUrl;
            _initialized = true;
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            AvatarCircle(
                              imageUrl: _localAvatarUrl,
                              initials: _localAvatarUrl?.isNotEmpty == true
                                  ? profile.initials
                                  : (AvatarCircle.initialsFromEmail(email) ??
                                      profile.initials),
                              seed: email,
                              size: 92,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Material(
                                color: AppColors.forest,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _uploadingPhoto ? null : _pickPhoto,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: _uploadingPhoto
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.lime))
                                        : const Icon(Icons.camera_alt_rounded,
                                            size: 18, color: AppColors.lime),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _uploadingPhoto ? null : _pickPhoto,
                          icon: const Icon(Icons.photo_library_outlined,
                              size: 18),
                          label: const Text('Change photo'),
                        ),
                        if (_localAvatarUrl?.isNotEmpty == true)
                          TextButton.icon(
                            onPressed: _uploadingPhoto
                                ? null
                                : () => _removePhoto(profile.avatarPath),
                            style: TextButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remove photo'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Personal details',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _profileField(
                    controller: _countryCtrl,
                    label: 'Country',
                    hint: 'e.g. Pakistan',
                    icon: Icons.public_rounded,
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _readOnlyProfileField(
                    label: 'Age',
                    value: _ageLabel(profile.ageAt(), profile.ageRange),
                    icon: Icons.cake_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _readOnlyProfileField(
                    label: 'Gender',
                    value: _genderLabel(profile.gender),
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Business details (optional)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: AppSpacing.md),
                  _profileField(
                    controller: _titleCtrl,
                    label: 'Professional title',
                    hint: 'e.g. Video Editor',
                    icon: Icons.work_outline_rounded,
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _profileField(
                    controller: _businessCtrl,
                    label: 'Business or studio name',
                    icon: Icons.business_outlined,
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _profileField(
                    controller: _locationCtrl,
                    label: 'City',
                    hint: 'e.g. Lahore',
                    icon: Icons.location_on_outlined,
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _profileField(
                    controller: _websiteCtrl,
                    label: 'Website or portfolio',
                    hint: 'https://example.com',
                    icon: Icons.language_rounded,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.ivory))
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _profileField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _readOnlyProfileField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Opacity(
      opacity: 0.78,
      child: InputDecorator(
        decoration: InputDecoration(
          enabled: false,
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
        ),
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

/// Post-crop adjustment stage. The native/web cropper supplies crop, zoom,
/// rotate and aspect presets; this screen adds reversible tonal controls and
/// rasterizes the final preview before sending it through the existing upload.
class _AvatarAdjustScreen extends StatefulWidget {
  final Future<Uint8List> imageBytes;

  const _AvatarAdjustScreen({required this.imageBytes});

  @override
  State<_AvatarAdjustScreen> createState() => _AvatarAdjustScreenState();
}

class _AvatarAdjustScreenState extends State<_AvatarAdjustScreen> {
  final _previewKey = GlobalKey();
  double _brightness = 0;
  double _contrast = 1;
  double _saturation = 1;
  double _rotation = 0;
  bool _flipX = false;
  bool _saving = false;

  List<double> _saturationMatrix(double amount) {
    const r = .213, g = .715, b = .072;
    final inv = 1 - amount;
    return [
      r * inv + amount,
      g * inv,
      b * inv,
      0,
      0,
      r * inv,
      g * inv + amount,
      b * inv,
      0,
      0,
      r * inv,
      g * inv,
      b * inv + amount,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _contrastMatrix(double amount) {
    final offset = 128 * (1 - amount);
    return [
      amount,
      0,
      0,
      0,
      offset,
      0,
      amount,
      0,
      0,
      offset,
      0,
      0,
      amount,
      0,
      offset,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _brightnessMatrix(double amount) => [
        1,
        0,
        0,
        0,
        amount * 255,
        0,
        1,
        0,
        0,
        amount * 255,
        0,
        0,
        1,
        0,
        amount * 255,
        0,
        0,
        0,
        1,
        0,
      ];

  Future<void> _save(Uint8List bytes) async {
    setState(() => _saving = true);
    try {
      final renderObject = _previewKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return;
      final image = await renderObject.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted || data == null) return;
      Navigator.of(context).pop(data.buffer.asUint8List());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare image: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() => setState(() {
        _brightness = 0;
        _contrast = 1;
        _saturation = 1;
        _rotation = 0;
        _flipX = false;
      });

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged, String valueText) {
    return Row(
      children: [
        SizedBox(width: 82, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 42, child: Text(valueText, textAlign: TextAlign.end)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        leadingWidth: 88,
        title: const Text('Adjust photo'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : () => widget.imageBytes.then(_save),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: widget.imageBytes,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: RepaintBoundary(
                        key: _previewKey,
                        child: ColoredBox(
                          color: scheme.surface,
                          child: Transform.rotate(
                            angle: _rotation,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(
                                  _flipX ? -1 : 1, 1, 1),
                              child: ColorFiltered(
                                colorFilter: ColorFilter.matrix(
                                    _saturationMatrix(_saturation)),
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.matrix(
                                      _contrastMatrix(_contrast)),
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.matrix(
                                        _brightnessMatrix(_brightness)),
                                    child: Image.memory(bytes,
                                        fit: BoxFit.contain),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Rotate 90°',
                            onPressed: () =>
                                setState(() => _rotation += math.pi / 2),
                            icon: const Icon(Icons.rotate_right_rounded),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Flip horizontally',
                            onPressed: () => setState(() => _flipX = !_flipX),
                            icon: const Icon(Icons.flip_rounded),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _reset,
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Reset'),
                          ),
                        ],
                      ),
                      _slider(
                          'Brightness',
                          _brightness,
                          -.4,
                          .4,
                          (v) => setState(() => _brightness = v),
                          _brightness.toStringAsFixed(1)),
                      _slider(
                          'Contrast',
                          _contrast,
                          .5,
                          1.5,
                          (v) => setState(() => _contrast = v),
                          _contrast.toStringAsFixed(1)),
                      _slider(
                          'Saturation',
                          _saturation,
                          0,
                          2,
                          (v) => setState(() => _saturation = v),
                          _saturation.toStringAsFixed(1)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
