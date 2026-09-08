import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  List<UserModel> _users = [];
  Map<String, String> _userDisplayById = {};
  List<MessageModel> _messages = [];
  String? _selectedRecipientId;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final allUsers = await _dbService.getAllUsers();
      final messages = await _dbService.getMessagesForCurrentUser();

      List<UserModel> users;
      if (currentUser != null) {
        final currentUserModel = await _dbService.getUser(currentUser.id);
        final role = currentUserModel?.role ?? 5;
        if (role <= 2) {
          users = allUsers;
        } else {
          final userRegion = (currentUserModel?.region ?? '').toLowerCase();
          if (userRegion.isEmpty) {
            users = allUsers.where((u) => u.id != currentUser.id).toList();
          } else {
            users =
                allUsers
                    .where(
                      (u) =>
                          u.id != currentUser.id &&
                          (u.region ?? '').toLowerCase() == userRegion,
                    )
                    .toList();
          }
        }
      } else {
        users = allUsers;
      }

      if (!mounted) return;
      setState(() {
        final userDisplayById = <String, String>{};
        for (final u in users) {
          userDisplayById[u.id] =
              (u.fullName?.trim().isNotEmpty == true)
                  ? u.fullName!.trim()
                  : u.email;
        }
        _users =
            users..sort((a, b) {
              final left = (a.fullName ?? a.email).toLowerCase();
              final right = (b.fullName ?? b.email).toLowerCase();
              return left.compareTo(right);
            });
        _userDisplayById = userDisplayById;
        _messages = messages;
        _selectedRecipientId =
            _selectedRecipientId ??
            (_users.isNotEmpty ? _users.first.id : null);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load messages: $e')));
    }
  }

  Future<void> _sendMessage() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    if (_selectedRecipientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a recipient first.')),
      );
      return;
    }

    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject and message are required.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await _dbService.sendMessage(
        MessageModel(
          senderId: currentUser.id,
          recipientId: _selectedRecipientId!,
          subject: subject,
          body: body,
        ),
      );

      _subjectController.clear();
      _bodyController.clear();
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openMessage(MessageModel message) async {
    if (!message.isRead &&
        message.recipientId == Supabase.instance.client.auth.currentUser?.id) {
      await _dbService.markMessageRead(message.id);
      await _loadData();
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final senderLabel =
        message.senderId == currentUserId
            ? 'You'
            : (_userDisplayById[message.senderId] ?? 'Unknown Sender');
    final recipientLabel =
        message.recipientId == currentUserId
            ? 'You'
            : (_userDisplayById[message.recipientId] ?? 'Unknown Recipient');

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(message.subject),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'From: $senderLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'To: $recipientLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(height: 24),
                Text(message.body),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteMessage(message);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMessage(MessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Message'),
            content: const Text('Delete this message from your inbox?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;
    try {
      await _dbService.deleteMessage(message.id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message deleted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete message: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildComposeCard(),
                    const SizedBox(height: 16),
                    _buildInboxCard(),
                  ],
                ),
              ),
    );
  }

  Widget _buildComposeCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compose Message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedRecipientId,
              decoration: const InputDecoration(
                labelText: 'Recipient',
                border: OutlineInputBorder(),
              ),
              items:
                  _users
                      .map(
                        (user) => DropdownMenuItem<String>(
                          value: user.id,
                          child: Text(user.fullName ?? user.email),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() => _selectedRecipientId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendMessage,
                icon:
                    _isSending
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send),
                label: const Text('Send Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inbox',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_messages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No messages yet.')),
              ),
            ..._messages.map((message) {
              final isIncoming =
                  message.recipientId ==
                  Supabase.instance.client.auth.currentUser?.id;
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              final senderLabel =
                  message.senderId == currentUserId
                      ? 'You'
                      : (_userDisplayById[message.senderId] ??
                          'Unknown Sender');
              return Card(
                elevation: 0,
                color: message.isRead ? Colors.white : Colors.green.shade50,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isIncoming
                            ? AppColors.primaryGreen.withValues(alpha: 0.12)
                            : AppColors.secondaryOrange.withValues(alpha: 0.12),
                    child: Icon(
                      isIncoming ? Icons.mark_email_unread : Icons.outbox,
                      color:
                          isIncoming
                              ? AppColors.primaryGreen
                              : AppColors.secondaryOrange,
                    ),
                  ),
                  title: Text(
                    message.subject,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'From: $senderLabel\n${message.body}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.createdAt == null
                            ? ''
                            : '${message.createdAt!.year}-${message.createdAt!.month.toString().padLeft(2, '0')}-${message.createdAt!.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Delete message',
                        onPressed: () => _deleteMessage(message),
                      ),
                    ],
                  ),
                  onTap: () => _openMessage(message),
                  onLongPress: () => _deleteMessage(message),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
