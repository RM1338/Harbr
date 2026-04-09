import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/app_providers.dart';
import '../../widgets/error_banner.dart';
import '../../../data/datasources/firebase_auth_datasource.dart';
import '../../../data/datasources/hive_cache_datasource.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _vehicleCtrl = TextEditingController();
  bool _editingVehicle = false;
  bool _savingVehicle = false;

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveVehicleNumber() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _savingVehicle = true);
    final ds = ref.read(firebaseAuthDSProvider);
    await ds.updateVehicleNumber(user.uid, _vehicleCtrl.text.trim());
    setState(() { _savingVehicle = false; _editingVehicle = false; });
    ref.invalidate(userProfileProvider);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Sign Out', style: AppTextStyles.headlineSm),
        content: Text('Are you sure you want to sign out?', style: AppTextStyles.bodyMd),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuthDataSource().signOut();
      // Router redirect handles navigation to onboarding
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Profile', style: AppTextStyles.headlineMd),
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
      ),
      body: profileAsync.when(
        data: (profile) {
          final displayName = profile?['displayName'] as String? ?? user?.displayName ?? 'User';
          final email = user?.email ?? 'N/A';
          final vehicleNumber = profile?['vehicleNumber'] as String? ?? '';
          if (!_editingVehicle && _vehicleCtrl.text.isEmpty) {
            _vehicleCtrl.text = vehicleNumber;
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Avatar + name
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                          style: AppTextStyles.headlineLg.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(displayName, style: AppTextStyles.headlineSm),
                    const SizedBox(height: 4),
                    Text(email, style: AppTextStyles.bodySm),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Vehicle number
              Text('VEHICLE', style: AppTextStyles.labelSm),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _editingVehicle ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.car, size: 18, color: AppColors.onSurfaceMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _editingVehicle
                          ? TextField(
                              controller: _vehicleCtrl,
                              style: AppTextStyles.bodyMd,
                              autofocus: true,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'MH02AB1234',
                                filled: false,
                              ),
                            )
                          : Text(
                              vehicleNumber.isEmpty ? 'Not set' : vehicleNumber,
                              style: AppTextStyles.bodyMd.copyWith(
                                color: vehicleNumber.isEmpty
                                    ? AppColors.onSurfaceDim
                                    : AppColors.onSurface,
                              ),
                            ),
                    ),
                    if (_editingVehicle)
                      _savingVehicle
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : TextButton(
                              onPressed: _saveVehicleNumber,
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: EdgeInsets.zero,
                              ),
                              child: Text('Save', style: AppTextStyles.bodySm.copyWith(color: AppColors.primary)),
                            )
                    else
                      GestureDetector(
                        onTap: () => setState(() => _editingVehicle = true),
                        child: const Icon(LucideIcons.pencil, size: 16, color: AppColors.onSurfaceMuted),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Notifications toggle
              Text('PREFERENCES', style: AppTextStyles.labelSm),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.bell, size: 18, color: AppColors.onSurfaceMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Notifications', style: AppTextStyles.bodyMd),
                    ),
                    Switch(
                      value: notificationsEnabled,
                      onChanged: (v) async {
                        ref.read(notificationsEnabledProvider.notifier).state = v;
                        await HiveCacheDataSource().setNotificationsEnabled(v);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Sign out
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error, width: 1),
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text('Sign Out'),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'harbr v1.0.0 · Harbour Gateway, Mumbai',
                  style: AppTextStyles.labelSm.copyWith(fontSize: 9),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => ErrorBanner(message: 'Failed to load profile. $e'),
      ),
    );
  }
}
