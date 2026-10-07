import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/error_note.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_field.dart';

/// What the sheet returns when an invite succeeds.
class InviteResult {
  const InviteResult(this.trip, this.username);

  final Trip trip;
  final String username;
}

/// Shows the "Invite by Username" bottom sheet.
///
/// Used from the Group Lobby by the trip leader.
Future<InviteResult?> showInviteMemberSheet(
  BuildContext context, {
  required Trip trip,
  required String myUsername,
  required Future<Trip> Function(String username) onInvite,
}) {
  return showModalBottomSheet<InviteResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        _InviteSheet(trip: trip, myUsername: myUsername, onInvite: onInvite),
  );
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({
    required this.trip,
    required this.myUsername,
    required this.onInvite,
  });

  final Trip trip;
  final String myUsername;
  final Future<Trip> Function(String username) onInvite;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final TextEditingController _controller = TextEditingController();

  String? _errorTitle;
  String? _errorMessage;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Trims whitespace, converts to lowercase,
  /// and removes any leading "@".
  String get _username {
    return _controller.text.trim().toLowerCase().replaceFirst(
      RegExp(r'^@+'),
      '',
    );
  }

  void _fail(String title, String message) {
    setState(() {
      _errorTitle = title;
      _errorMessage = message;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_loading) return;

    final username = _username;
    final currentUsername = widget.myUsername.trim().toLowerCase();

    if (username.isEmpty) {
      _fail(
        'USERNAME REQUIRED',
        'Enter the username of the friend you want to invite.',
      );
      return;
    }

    if (username == currentUsername) {
      _fail(
        'THAT\'S YOU',
        'You are already in this trip. Enter a friend\'s username instead.',
      );
      return;
    }

    final alreadyMember = widget.trip.members.any(
      (member) => member.username.trim().toLowerCase() == username,
    );

    if (alreadyMember) {
      _fail(
        'ALREADY IN THIS TRIP',
        '@$username is already a member of this trip.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorTitle = null;
      _errorMessage = null;
    });

    try {
      final updatedTrip = await widget.onInvite(username);

      if (!mounted) return;

      Navigator.of(context).pop(InviteResult(updatedTrip, username));
    } on TripException catch (e) {
      if (!mounted) return;
      _fail(e.title, e.message);
    } catch (_) {
      if (!mounted) return;

      _fail('SOMETHING WENT WRONG', 'Check your connection and try again.');
    }
  }

  void _clearError() {
    if (_errorTitle == null && _errorMessage == null) return;

    setState(() {
      _errorTitle = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bottom sheet handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                'Invite by Username',
                style: AppText.ui(17, FontWeight.w800, color: AppColors.navy),
              ),

              const SizedBox(height: 6),

              // Description
              Text(
                'Add a friend using their Taralets username. '
                'They will appear in the lobby as Not Ready until they confirm.',
                style: AppText.ui(
                  12,
                  FontWeight.w400,
                  color: AppColors.muted,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 16),

              // Username field
              TaraletsField(
                hint: 'username',
                controller: _controller,
                icon: Text(
                  '@',
                  style: AppText.ui(
                    14,
                    FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                onChanged: (_) => _clearError(),
              ),

              const SizedBox(height: 8),

              // Username tips
              Text.rich(
                TextSpan(
                  style: AppText.ui(
                    12,
                    FontWeight.w400,
                    color: AppColors.muted,
                  ),
                  children: [
                    const TextSpan(text: 'Tip: Try '),
                    TextSpan(
                      text: '@rhea',
                      style: AppText.mono(
                        12,
                        FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                    const TextSpan(text: ', '),
                    TextSpan(
                      text: '@miguel',
                      style: AppText.mono(
                        12,
                        FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                    const TextSpan(text: ' or '),
                    TextSpan(
                      text: '@bea',
                      style: AppText.mono(
                        12,
                        FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),

              // Error message
              if (_errorTitle != null) ...[
                const SizedBox(height: 12),
                ErrorNote(title: _errorTitle!, message: _errorMessage ?? ''),
              ],

              const SizedBox(height: 16),

              // Send invite button
              TaraletsButton.orange(
                label: 'Send Invite',
                isLoading: _loading,
                onPressed: _submit,
              ),

              // Cancel
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _loading ? null : () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    margin: const EdgeInsets.only(top: 2),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancel',
                      style: AppText.ui(
                        13,
                        FontWeight.w400,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
