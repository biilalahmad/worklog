import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/theme_mode_provider.dart';
import '../../../../core/config/app_info.dart';
import '../../../../core/csv/csv_export_service.dart';
import '../../../../core/csv/csv_import_service.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../../core/widgets/money_display.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../work/presentation/providers/work_providers.dart';
import '../../domain/profile.dart';
import '../providers/profile_providers.dart';
import '../widgets/avatar_circle.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final email = ref.watch(authRepositoryProvider).currentUserEmail;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text(Failure.from(e).message)),
        data: (profile) {
          if (profile == null) return const LoadingIndicator();
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              AppInsets.belowNavigation(context, gap: 48),
            ),
            children: [
              _Header(profile: profile, email: email),
              const SizedBox(height: 24),
              const _SectionLabel('Preferences'),
              _PreferencesCard(profile: profile),
              const SizedBox(height: 24),
              const _SectionLabel('Fitness Tracking'),
              _FitnessToggleCard(profile: profile),
              const SizedBox(height: 24),
              const _SectionLabel('Account'),
              _AccountCard(),
              const SizedBox(height: 24),
              const _SectionLabel('Data'),
              const _DataCard(),
              const SizedBox(height: 24),
              const _SectionLabel('About'),
              const _AboutCard(),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: AppColors.mutedText)),
    );
  }
}

class _Header extends StatelessWidget {
  final UserProfile profile;
  final String? email;
  const _Header({required this.profile, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.forestLight],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
              color: AppColors.forest.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.lime.withValues(alpha: 0.85), width: 2),
                ),
                child: AvatarCircle(
                  imageUrl: profile.avatarUrl,
                  initials: profile.avatarUrl?.isNotEmpty == true
                      ? profile.initials
                      : (AvatarCircle.initialsFromEmail(email) ??
                          profile.initials),
                  seed: email,
                  size: 62,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                ),
                if (profile.professionalTitle?.trim().isNotEmpty == true ||
                    profile.businessName?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (profile.professionalTitle?.trim().isNotEmpty == true)
                        profile.professionalTitle!.trim(),
                      if (profile.businessName?.trim().isNotEmpty == true)
                        profile.businessName!.trim(),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
                if (email != null) ...[
                  const SizedBox(height: 2),
                  Text(email!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70)),
                ],
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => context.push('/profile/edit'),
            style: IconButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.forest),
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Profile',
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends ConsumerWidget {
  final UserProfile profile;
  const _PreferencesCard({required this.profile});

  Future<void> _editInvoiceName(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: profile.invoiceName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Name for Invoices'),
        content: TextField(
          controller: ctrl,
          decoration:
              const InputDecoration(hintText: 'e.g. your business name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(invoiceName: result);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.save(e).message)));
      }
    }
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final result = await AppSelectSheet.show<String>(
      context: context,
      title: 'Select Currency',
      value: ref.read(defaultCurrencyProvider),
      options: supportedCurrencies
          .map((c) => AppSelectOption(value: c, label: c))
          .toList(),
    );
    if (result == null) return;
    ref.read(currencyDisplayOverrideProvider.notifier).state =
        CurrencyDisplayOverride(userId: profile.id, currency: result);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(defaultCurrency: result);
    } catch (e) {
      ref.read(currencyDisplayOverrideProvider.notifier).state = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.save(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesIssue = ref.watch(currencyRatesIssueProvider);
    final selectedCurrency = ref.watch(defaultCurrencyProvider);
    final themeMode = ref.watch(themeModeProvider);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.currency_exchange_rounded),
            title: const Text('Select Currency'),
            subtitle: const Text(
                'Display amounts use daily reference rates; saved values stay in their original currency'),
            trailing: Text(selectedCurrency,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => _pickCurrency(context, ref),
          ),
          if (ratesIssue != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 17, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ratesIssue,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Your Name for Invoices'),
            subtitle: Text(profile.invoiceName?.isNotEmpty == true
                ? profile.invoiceName!
                : 'Same as account name'),
            onTap: () => _editInvoiceName(context, ref),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.brightness_6_outlined),
                const SizedBox(width: 16),
                const Expanded(child: Text('Theme')),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) =>
                      ref.read(themeModeProvider.notifier).setMode(s.first),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('AI Assistant'),
            subtitle: const Text('Ask questions and manage your workspace'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/assistant'),
          ),
        ],
      ),
    );
  }
}

class _FitnessToggleCard extends ConsumerWidget {
  final UserProfile profile;
  const _FitnessToggleCard({required this.profile});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enable) async {
    if (!enable) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hide Gym & Diet tracking?'),
          content: const Text(
              'Your existing workout and diet data will be kept, just hidden from the nav bar. You can turn this back on anytime.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hide Gym')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref.read(profileRepositoryProvider).setGymEnabled(enable);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.save(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enable Gym & Diet Tracking'),
        subtitle: const Text(
            'Turn this on to track workouts, meals, and body stats. You can change this anytime.'),
        value: profile.gymEnabled,
        onChanged: (v) => _toggle(context, ref, v),
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset_rounded),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/profile/change-password'),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Logout'),
            onTap: () => _confirmLogout(context, ref),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.delete_forever_rounded,
                color: Theme.of(context).colorScheme.error),
            title: Text('Delete Account',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text(
            'You can sign back in any time with the same email and password.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authRepositoryProvider).signOut();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'We’ll first send a verification code to your registered email. Nothing is deleted unless that code is verified and you confirm again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(context);
              context.push('/profile/delete-account');
            },
            child: const Text('Continue to verification'),
          ),
        ],
      ),
    );
  }
}

class _DataCard extends ConsumerStatefulWidget {
  const _DataCard();

  @override
  ConsumerState<_DataCard> createState() => _DataCardState();
}

class _DataCardState extends ConsumerState<_DataCard> {
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final service = CsvExportService(
        clientRepository: ref.read(clientRepositoryProvider),
        workRepository: ref.read(workRepositoryProvider),
        financeRepository: ref.read(financeRepositoryProvider),
      );
      await service.exportAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importIncome() async {
    setState(() => _importing = true);
    try {
      final clients = await ref.read(clientRepositoryProvider).getAllClients();
      final service = CsvImportService(
          financeRepository: ref.read(financeRepositoryProvider));
      final result = await service.importIncomeCsv(clients);
      if (!mounted) return;
      if (result == null) return; // cancelled
      final message = result.skipped == 0
          ? 'Imported ${result.imported} income record(s).'
          : 'Imported ${result.imported}, skipped ${result.skipped} (check client names match exactly).';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          ListTile(
            leading: _exporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined),
            title: const Text('Export Data (CSV)'),
            subtitle: const Text('Clients, work entries, income and expenses'),
            onTap: _exporting ? null : _export,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: _importing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_upload_outlined),
            title: const Text('Import Income (CSV)'),
            subtitle: const Text('Same column layout as the exported file'),
            onTap: _importing ? null : _importIncome,
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  Future<void> _open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('App Version'),
            trailing: Text(AppInfo.version,
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _open(Uri.parse(AppInfo.privacyPolicyUrl)),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _open(Uri.parse(AppInfo.termsOfServiceUrl)),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text('Send Feedback'),
            onTap: () => _open(Uri(
              scheme: 'mailto',
              path: AppInfo.supportEmail,
              query: 'subject=WorkLog Feedback',
            )),
          ),
        ],
      ),
    );
  }
}
