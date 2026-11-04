import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../repositories/notifications_repository.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../data/friends_repository.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _emailController = TextEditingController();
  Friend? _searchResult;
  String? _searchError;
  bool _searching = false;
  bool _adding = false;
  final Set<String> _workingRequestIds = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshFriendData(),
    );
  }

  void _refreshFriendData() {
    if (!mounted) return;
    if (!ref.read(incomingFriendRequestsProvider).isLoading) {
      ref.invalidate(incomingFriendRequestsProvider);
    }
    if (!ref.read(outgoingFriendRequestsProvider).isLoading) {
      ref.invalidate(outgoingFriendRequestsProvider);
    }
    if (!ref.read(friendsProvider).isLoading) {
      ref.invalidate(friendsProvider);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _searchResult = null;
        _searchError = 'Enter your friend’s email address.';
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _searchResult = null;
    });
    try {
      final friend = await ref
          .read(friendsRepositoryProvider)
          .findByEmail(email);
      if (mounted) setState(() => _searchResult = friend);
    } catch (error) {
      if (mounted) {
        setState(
          () => _searchError = ref
              .read(friendsRepositoryProvider)
              .errorMessage(error, 'Could not find that account.'),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addFriend() async {
    final result = _searchResult;
    if (result == null) return;
    setState(() => _adding = true);
    try {
      await ref.read(friendsRepositoryProvider).addByEmail(result.email);
      ref.invalidate(friendsProvider);
      ref.invalidate(outgoingFriendRequestsProvider);
      if (!mounted) return;
      setState(() {
        _searchResult = null;
        _emailController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${result.fullName}.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref
                  .read(friendsRepositoryProvider)
                  .errorMessage(error, 'Could not add this friend.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    try {
      await ref.read(friendsRepositoryProvider).remove(friend.id);
      ref.invalidate(friendsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${friend.fullName} removed from friends.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref
                  .read(friendsRepositoryProvider)
                  .errorMessage(error, 'Could not remove this friend.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _respondToRequest(
    FriendRequestItem request, {
    required bool accept,
  }) async {
    setState(() => _workingRequestIds.add(request.requestId));
    try {
      final repository = ref.read(friendsRepositoryProvider);
      if (accept) {
        await repository.acceptRequest(request.requestId);
      } else {
        await repository.declineRequest(request.requestId);
      }
      ref.invalidate(incomingFriendRequestsProvider);
      ref.invalidate(outgoingFriendRequestsProvider);
      ref.invalidate(notificationsProvider);
      if (accept) ref.invalidate(friendsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'You and ${request.fullName} are now friends.'
                  : 'Friend request declined.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref
                  .read(friendsRepositoryProvider)
                  .errorMessage(error, 'Could not update friend request.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _workingRequestIds.remove(request.requestId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);
    final incomingAsync = ref.watch(incomingFriendRequestsProvider);
    final outgoingAsync = ref.watch(outgoingFriendRequestsProvider);
    final alreadyFriend =
        friendsAsync.valueOrNull?.any(
          (friend) => friend.id == _searchResult?.id,
        ) ??
        false;
    final requestSent =
        outgoingAsync.valueOrNull?.any(
          (request) => request.userId == _searchResult?.id,
        ) ??
        false;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(
          'Friends',
          style: AppText.ui(18, FontWeight.w800, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: () async {
          ref.invalidate(friendsProvider);
          ref.invalidate(incomingFriendRequestsProvider);
          ref.invalidate(outgoingFriendRequestsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              'Add a friend',
              style: AppText.ui(17, FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 5),
            Text(
              'Find someone by the email address they use in Taralets.',
              style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Friend’s email',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    minimumSize: const Size(52, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search_rounded),
                ),
              ],
            ),
            if (_searchError != null) ...[
              const SizedBox(height: 8),
              Text(
                _searchError!,
                style: AppText.ui(12, FontWeight.w500, color: AppColors.red),
              ),
            ],
            if (_searchResult != null) ...[
              const SizedBox(height: 12),
              _FriendTile(
                friend: _searchResult!,
                trailing: alreadyFriend
                    ? Text(
                        'Friends',
                        style: AppText.ui(
                          12,
                          FontWeight.w700,
                          color: AppColors.green,
                        ),
                      )
                    : requestSent
                    ? Text(
                        'Pending',
                        style: AppText.ui(
                          12,
                          FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _adding ? null : _addFriend,
                        icon: _adding
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 17,
                              ),
                        label: const Text('Send request'),
                      ),
              ),
            ],
            const SizedBox(height: 28),
            incomingAsync.when(
              loading: () =>
                  const LinearProgressIndicator(color: AppColors.orange),
              error: (error, _) => Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    ref.invalidate(incomingFriendRequestsProvider);
                    ref.invalidate(outgoingFriendRequestsProvider);
                  },
                  child: const Text('Could not load friend requests. Retry'),
                ),
              ),
              data: (incoming) => outgoingAsync.when(
                loading: () =>
                    const LinearProgressIndicator(color: AppColors.orange),
                error: (error, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(outgoingFriendRequestsProvider),
                    child: const Text('Could not load sent requests. Retry'),
                  ),
                ),
                data: (outgoing) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Friend Requests (${incoming.length + outgoing.length})',
                      style: AppText.ui(
                        17,
                        FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (incoming.isEmpty && outgoing.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Received and sent friend requests will appear here.',
                          textAlign: TextAlign.center,
                          style: AppText.ui(
                            12,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    if (incoming.isNotEmpty) ...[
                      Text(
                        'Received',
                        style: AppText.ui(
                          12,
                          FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final request in incoming)
                        _IncomingRequestTile(
                          request: request,
                          working: _workingRequestIds.contains(
                            request.requestId,
                          ),
                          onAccept: () =>
                              _respondToRequest(request, accept: true),
                          onDecline: () =>
                              _respondToRequest(request, accept: false),
                        ),
                    ],
                    if (outgoing.isNotEmpty) ...[
                      Text(
                        'Sent',
                        style: AppText.ui(
                          12,
                          FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final request in outgoing)
                        _FriendTile(
                          friend: Friend(
                            id: request.userId,
                            fullName: request.fullName,
                            email: request.email,
                          ),
                          trailing: Text(
                            'Pending',
                            style: AppText.ui(
                              12,
                              FontWeight.w700,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            friendsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(color: AppColors.orange),
                ),
              ),
              error: (error, _) => Column(
                children: [
                  Text(
                    'Could not load your friends.',
                    style: AppText.ui(
                      13,
                      FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(friendsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (friends) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'My Friends (${friends.length})',
                    style: AppText.ui(
                      17,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (friends.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Your friends will appear here. Add someone using their Taralets email.',
                        textAlign: TextAlign.center,
                        style: AppText.ui(
                          12,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  for (final friend in friends) ...[
                    _FriendTile(
                      friend: friend,
                      trailing: IconButton(
                        tooltip: 'Remove friend',
                        onPressed: () => _removeFriend(friend),
                        icon: const Icon(
                          Icons.person_remove_alt_1_rounded,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingRequestTile extends StatelessWidget {
  const _IncomingRequestTile({
    required this.request,
    required this.working,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequestItem request;
  final bool working;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Avatar(name: request.fullName, size: 42),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(
                      13,
                      FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(
                      11,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: working ? null : onDecline,
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: working ? null : onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                ),
                child: working
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Accept'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.trailing});

  final Friend friend;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Avatar(name: friend.fullName, size: 42),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                friend.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(13, FontWeight.w700, color: AppColors.navy),
              ),
              const SizedBox(height: 2),
              Text(
                friend.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
              ),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}
