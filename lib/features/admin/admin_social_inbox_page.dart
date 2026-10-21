import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_service.dart';
import '../../services/api_service.dart';

class AdminSocialInboxPage extends StatefulWidget {
  const AdminSocialInboxPage({super.key});

  @override
  State<AdminSocialInboxPage> createState() => _AdminSocialInboxPageState();
}

class _AdminSocialInboxPageState extends State<AdminSocialInboxPage> {
  final _dbService = DatabaseService();
  final _replyController = TextEditingController();
  final _uuid = const Uuid();

  bool _isLoading = true;
  bool _isSending = false;
  List<Map<String, dynamic>> _conversations = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  String? _selectedConversationId;
  String? _selectedChannel;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final rows = await ApiService().getAll(
        'social_conversations', orderBy: 'last_message_at',
        orderDir: 'DESC', limit: 500,
      );

      final list = List<Map<String, dynamic>>.from(rows);
      final seeded = list.isEmpty ? _dummyConversations() : list;
      if (!mounted) return;
      setState(() {
        _conversations = seeded;
        if (_selectedConversationId == null && seeded.isNotEmpty) {
          _selectedConversationId = seeded.first['id'].toString();
          _selectedChannel = seeded.first['channel'].toString();
        }
      });
      await _loadMessages();
    } catch (e) {
      _showInfo('Failed to load conversations: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages() async {
    if (_selectedConversationId == null) {
      setState(() => _messages = <Map<String, dynamic>>[]);
      return;
    }
    try {
      final rows = await ApiService().getAll(
        'social_messages', filter: {'conversation_id': _selectedConversationId},
        orderBy: 'sent_at', orderDir: 'ASC', limit: 500,
      );
      if (!mounted) return;
      final dbMessages = List<Map<String, dynamic>>.from(rows);
      setState(
        () =>
            _messages =
                dbMessages.isEmpty
                    ? _dummyMessages(_selectedConversationId!)
                    : dbMessages,
      );
    } catch (e) {
      _showInfo('Failed to load messages: $e');
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty ||
        _selectedConversationId == null ||
        _selectedChannel == null) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final user = ApiService().cachedUser;
      await _dbService.insertWithOfflineQueue(
        table: 'social_messages',
        payload: {
          'conversation_id': _selectedConversationId,
          'channel': _selectedChannel,
          'external_message_id': 'local-${_uuid.v4()}',
          'sender_name': (user?['email'] ?? 'Admin'),
          'sender_id': ApiService().currentUserId,
          'body': text,
          'sent_at': DateTime.now().toUtc().toIso8601String(),
          'raw_payload': {'origin': 'admin_ui', 'status': 'pending_dispatch'},
        },
      );

      await ApiService().patch('social_conversations', _selectedConversationId!, {
            'last_message_preview': text,
            'last_message_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });

      _replyController.clear();
      await _loadMessages();
      await _loadConversations();
      _showInfo('Reply saved. Bot can dispatch it to channel.');
    } catch (e) {
      _showInfo('Failed to send reply: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Inbox'),
        actions: [
          IconButton(
            onPressed: _loadConversations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                children: [
                  SizedBox(width: 340, child: _buildConversationList()),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildThread()),
                ],
              ),
    );
  }

  Widget _buildConversationList() {
    if (_conversations.isEmpty) {
      return const Center(child: Text('No conversations found.'));
    }
    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = _conversations[index];
        final id = c['id'].toString();
        final selected = id == _selectedConversationId;
        return ListTile(
          selected: selected,
          leading: Icon(
            (c['channel'] ?? '').toString() == 'facebook'
                ? Icons.facebook
                : Icons.chat,
          ),
          title: Text((c['participant_display'] ?? 'Unknown').toString()),
          subtitle: Text(
            (c['last_message_preview'] ?? 'No message').toString(),
            maxLines: 1,
          ),
          onTap: () async {
            setState(() {
              _selectedConversationId = id;
              _selectedChannel = (c['channel'] ?? '').toString();
            });
            await _loadMessages();
          },
        );
      },
    );
  }

  Widget _buildThread() {
    if (_selectedConversationId == null) {
      return const Center(child: Text('Select a conversation.'));
    }
    return Column(
      children: [
        Expanded(
          child:
              _messages.isEmpty
                  ? const Center(child: Text('No messages yet.'))
                  : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isMine =
                          (m['sender_id'] ?? '').toString() ==
                          (ApiService().currentUserId ?? '');
                      return Align(
                        alignment:
                            isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(maxWidth: 520),
                          decoration: BoxDecoration(
                            color:
                                isMine
                                    ? Colors.blue.shade50
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (m['sender_name'] ?? 'Unknown').toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text((m['body'] ?? '').toString()),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Write reply...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSending ? null : _sendReply,
                child:
                    _isSending
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Reply'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> _dummyConversations() {
    final now = DateTime.now().toUtc().toIso8601String();
    return [
      {
        'id': 'dummy-fb-1',
        'channel': 'facebook',
        'participant_display': 'Longhorn Publishers Page',
        'participant_phone': null,
        'last_message_preview': 'Can you share the latest catalogue?',
        'last_message_at': now,
        'updated_at': now,
      },
      {
        'id': 'dummy-wa-1',
        'channel': 'whatsapp',
        'participant_display': '0798734442',
        'participant_phone': '0798734442',
        'last_message_preview': 'Need pricing for Grade 7 books.',
        'last_message_at': now,
        'updated_at': now,
      },
    ];
  }

  List<Map<String, dynamic>> _dummyMessages(String conversationId) {
    final me = ApiService().currentUserId ?? 'admin-user';
    if (conversationId == 'dummy-fb-1') {
      return [
        {
          'id': 'dummy-fb-msg-1',
          'sender_name': 'Longhorn Publishers Page',
          'sender_id': 'fb-user-1',
          'body': 'Hello, we are interested in your school pipeline report.',
          'sent_at':
              DateTime.now()
                  .toUtc()
                  .subtract(const Duration(hours: 2))
                  .toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'id': 'dummy-fb-msg-2',
          'sender_name': 'Admin',
          'sender_id': me,
          'body': 'Sure, I can share that. Which region do you need first?',
          'sent_at':
              DateTime.now()
                  .toUtc()
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      ];
    }
    return [
      {
        'id': 'dummy-wa-msg-1',
        'sender_name': '0798734442',
        'sender_id': 'wa-user-1',
        'body': 'Please send brochure and order process.',
        'sent_at':
            DateTime.now()
                .toUtc()
                .subtract(const Duration(hours: 3))
                .toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      {
        'id': 'dummy-wa-msg-2',
        'sender_name': 'Admin',
        'sender_id': me,
        'body': 'Shared. I can also book a call tomorrow morning.',
        'sent_at':
            DateTime.now()
                .toUtc()
                .subtract(const Duration(hours: 2))
                .toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    ];
  }
}
