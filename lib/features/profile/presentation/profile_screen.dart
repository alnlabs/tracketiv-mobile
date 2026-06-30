import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/profile.dart';
import '../../../shared/models/profile_stats.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/weight_utils.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/session_sync_provider.dart';
import '../data/profile_repository.dart';
import '../providers/profile_provider.dart';
import '../../legal/presentation/legal_screens.dart';
import '../widgets/profile_stats_section.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../../shared/widgets/app_version_label.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploading = false;
  DateTime? _dateOfBirth;
  String? _gender;
  String _weightUnit = 'kg';

  static const _genderOptions = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
    'prefer_not_to_say': 'Prefer not to say',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadProfileFields(Profile? profile) {
    _nameController.text = profile?.displayName ?? '';
    _usernameController.text = profile?.username ?? '';
    _bioController.text = profile?.bio ?? '';
    _heightController.text = profile?.heightCm?.toString() ?? '';
    _countryController.text = profile?.country ?? '';
    _cityController.text = profile?.city ?? '';
    _phoneController.text = profile?.phone ?? '';
    _dateOfBirth = profile?.dateOfBirth;
    _gender = profile?.gender;
    _weightUnit = profile?.weightUnit ?? 'kg';
    if (profile?.weightKg != null) {
      final display = WeightUtils.kgToDisplay(profile!.weightKg!, _weightUnit);
      _weightController.text = display.toStringAsFixed(1);
    } else {
      _weightController.text = '';
    }
  }

  Future<void> _saveProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final usernameError = Validators.username(_usernameController.text);
    if (usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(usernameError)));
      return;
    }

    final heightText = _heightController.text.trim();
    double? heightCm;
    if (heightText.isNotEmpty) {
      heightCm = double.tryParse(heightText);
      if (heightCm == null || heightCm <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid height in cm')),
        );
        return;
      }
    }

    final weightText = _weightController.text.trim();
    double? weightKg;
    if (weightText.isNotEmpty) {
      final displayWeight = double.tryParse(weightText);
      if (displayWeight == null || displayWeight <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid weight in $_weightUnit')),
        );
        return;
      }
      weightKg = WeightUtils.displayToKg(displayWeight, _weightUnit);
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            userId: user.id,
            update: ProfileUpdate(
              displayName: _nameController.text.trim(),
              username: _usernameController.text.trim(),
              bio: _bioController.text.trim(),
              clearBio: _bioController.text.trim().isEmpty,
              dateOfBirth: _dateOfBirth,
              clearDateOfBirth: _dateOfBirth == null,
              gender: _gender,
              clearGender: _gender == null,
              heightCm: heightCm,
              clearHeight: heightText.isEmpty,
              weightKg: weightKg,
              clearWeight: weightText.isEmpty,
              country: _countryController.text.trim(),
              clearCountry: _countryController.text.trim().isEmpty,
              city: _cityController.text.trim(),
              clearCity: _cityController.text.trim().isEmpty,
              phone: _phoneController.text.trim(),
              clearPhone: _phoneController.text.trim().isEmpty,
              weightUnit: _weightUnit,
            ),
          );
      ref.invalidate(currentProfileProvider);
      setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toUserMessage())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      final url = await ref.read(profileRepositoryProvider).uploadAvatar(
            userId: user.id,
            bytes: bytes,
            fileName: image.name,
          );
      await ref.read(profileRepositoryProvider).updateProfile(
            userId: user.id,
            update: ProfileUpdate(avatarUrl: url),
          );
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Avatar upload failed. ${e.toUserMessage()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    invalidateUserSessionData(ref);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final user = ref.watch(currentUserProvider);
    final statsAsync = user != null
        ? ref.watch(userProfileStatsProvider(user.id))
        : const AsyncValue<ProfileStats?>.loading();

    return Scaffold(
      appBar: TracketivAppBar(
        title: 'Profile',
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                profileAsync.whenData((p) {
                  _loadProfileFields(p);
                  setState(() => _isEditing = true);
                });
              },
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toUserMessage())),
        data: (profile) {
          if (!_isEditing && _nameController.text.isEmpty && profile != null) {
            _loadProfileFields(profile);
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              listScrollBottomPadding(context),
            ),
            children: [
              _ProfileHeader(
                profile: profile,
                userEmail: user?.email,
                isUploading: _isUploading,
                onPickAvatar: _pickAvatar,
              ),
              const SizedBox(height: 12),
              if (_isEditing) ...[
                _sectionTitle(context, 'Account'),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixText: '@',
                    isDense: true,
                  ),
                  autocorrect: false,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                _sectionTitle(context, 'About'),
                TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell your group what you are working toward...',
                    alignLabelWithHint: true,
                    isDense: true,
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 10),
                ListTile(
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date of birth'),
                  subtitle: Text(
                    _dateOfBirth != null
                        ? DateFormat.yMMMd().format(_dateOfBirth!)
                        : 'Not set',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_dateOfBirth != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _dateOfBirth = null),
                        ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateOfBirth ?? DateTime(1995),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _dateOfBirth = picked);
                  },
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Not set')),
                    ..._genderOptions.entries.map(
                      (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 14),
                _sectionTitle(context, 'Fitness'),
                TextField(
                  controller: _heightController,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    hintText: 'e.g. 175',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _weightController,
                  decoration: InputDecoration(
                    labelText: 'Current weight (${WeightUtils.unitLabel(_weightUnit)})',
                    hintText: _weightUnit == 'lbs' ? 'e.g. 180' : 'e.g. 82',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                Text('Preferred weight unit', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'kg', label: Text('kg')),
                    ButtonSegment(value: 'lbs', label: Text('lbs')),
                  ],
                  selected: {_weightUnit},
                  onSelectionChanged: (s) {
                    final newUnit = s.first;
                    final current = double.tryParse(_weightController.text.trim());
                    if (current != null) {
                      final asKg = WeightUtils.displayToKg(current, _weightUnit);
                      final converted = WeightUtils.kgToDisplay(asKg, newUnit);
                      _weightController.text = converted.toStringAsFixed(1);
                    }
                    setState(() => _weightUnit = newUnit);
                  },
                ),
                const SizedBox(height: 14),
                _sectionTitle(context, 'Contact & location'),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone', isDense: true),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _countryController,
                  decoration: const InputDecoration(labelText: 'Country', isDense: true),
                ),
                const SizedBox(height: 16),
                LoadingButton(onPressed: _saveProfile, label: 'Save', isLoading: _isSaving),
                TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('Cancel'),
                ),
              ] else ...[
                if (profile?.bio != null && profile!.bio!.isNotEmpty) ...[
                  Text(
                    profile.bio!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ],
                statsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (e, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Could not load stats: ${e.toUserMessage()}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  data: (stats) {
                    if (stats == null) return const SizedBox.shrink();
                    return ProfileStatsSection(stats: stats);
                  },
                ),
                const SizedBox(height: 12),
                Text('Details', style: AppTypography.sectionTitle(context)),
                const SizedBox(height: 6),
                _ProfileInfoCard(profile: profile),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              ListTile(
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.info_outline, size: 20),
                title: Text('About', style: Theme.of(context).textTheme.labelLarge),
                onTap: () => context.push('/about'),
              ),
              ListTile(
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.gavel_outlined, size: 20),
                title: Text('Disclaimer', style: Theme.of(context).textTheme.labelLarge),
                onTap: () => context.push('/disclaimer'),
              ),
              ListTile(
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.privacy_tip_outlined, size: 20),
                title: Text('Privacy Policy', style: Theme.of(context).textTheme.labelLarge),
                onTap: () => context.push('/privacy-policy'),
              ),
              ListTile(
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.feedback_outlined, size: 20),
                title: Text('Send feedback', style: Theme.of(context).textTheme.labelLarge),
                subtitle: Text(
                  'Suggestions or issues',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                onTap: () => context.push('/feedback'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: AppVersionLabel(),
              ),
              ListTile(
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(Icons.logout, size: 20, color: Theme.of(context).colorScheme.error),
                title: Text(
                  'Sign out',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                onTap: _signOut,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: AppTypography.sectionTitle(context)),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.userEmail,
    required this.isUploading,
    required this.onPickAvatar,
  });

  final Profile? profile;
  final String? userEmail;
  final bool isUploading;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage:
                  profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null,
              child: profile?.avatarUrl == null
                  ? Text(profile?.initials ?? 'U', style: const TextStyle(fontSize: 22))
                  : null,
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Material(
                color: colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: isUploading ? null : onPickAvatar,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: isUploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.camera_alt, size: 14, color: colorScheme.onPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.publicName ?? 'User',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.profileName(context),
              ),
              if (profile?.username != null)
                Text(
                  '@${profile!.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.primary),
                ),
              if (userEmail != null && userEmail!.isNotEmpty)
                Text(
                  userEmail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    if (profile == null) return const SizedBox.shrink();

    final rows = <(IconData, String, String)>[];

    if (profile!.age != null) {
      rows.add((Icons.cake_outlined, 'Age', '${profile!.age} years'));
    }
    if (profile!.genderLabel != null) {
      rows.add((Icons.person_outline, 'Gender', profile!.genderLabel!));
    }
    if (profile!.heightCm != null) {
      rows.add((Icons.height, 'Height', '${profile!.heightCm!.toStringAsFixed(0)} cm'));
    }
    if (profile!.weightDisplay != null) {
      rows.add((Icons.monitor_weight_outlined, 'Weight', profile!.weightDisplay!));
    }
    if (profile!.location != null) {
      rows.add((Icons.location_on_outlined, 'Location', profile!.location!));
    }
    if (profile!.phone != null && profile!.phone!.isNotEmpty) {
      rows.add((Icons.phone_outlined, 'Phone', profile!.phone!));
    }

    if (rows.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Add more details so your group knows you better.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: rows.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(row.$1, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: Text(
                      row.$2,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
