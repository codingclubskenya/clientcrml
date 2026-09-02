import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../database/database_service.dart';
import 'event_date_format.dart';

class EventPhotosPage extends StatefulWidget {
  const EventPhotosPage({super.key});

  @override
  State<EventPhotosPage> createState() => _EventPhotosPageState();
}

class _EventPhotosPageState extends State<EventPhotosPage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;

  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map
      ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String?
      : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = _eventId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final photos = await _dbService.getEventPhotos(id);
      setState(() => _photos = photos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadPhoto() async {
    final id = _eventId;
    if (id == null) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) return;

      setState(() => _loading = true);

      final file = File(image.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      await _supabase.storage.from('event_photos').upload(fileName, file);

      final imageUrl = _supabase.storage.from('event_photos').getPublicUrl(fileName);

      final currentUser = _supabase.auth.currentUser;
      await _dbService.uploadEventPhoto({
        'event_id': id,
        'agent_id': currentUser?.id,
        'photo_url': imageUrl,
        'photo_path': fileName,
        'photo_type': 'General',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully!')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _uploadFromGallery() async {
    final id = _eventId;
    if (id == null) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      setState(() => _loading = true);

      final file = File(image.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      await _supabase.storage.from('event_photos').upload(fileName, file);

      final imageUrl = _supabase.storage.from('event_photos').getPublicUrl(fileName);

      final currentUser = _supabase.auth.currentUser;
      await _dbService.uploadEventPhoto({
        'event_id': id,
        'agent_id': currentUser?.id,
        'photo_url': imageUrl,
        'photo_path': fileName,
        'photo_type': 'Gallery',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully!')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final photoPath = photo['photo_path']?.toString();
        if (photoPath != null && photoPath.isNotEmpty) {
          await _supabase.storage.from('event_photos').remove([photoPath]);
        }

        await _supabase.from('event_photos').delete().eq('id', photo['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo deleted')),
          );
        }
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  Future<void> _editCaption(Map<String, dynamic> photo) async {
    final captionController = TextEditingController(text: photo['caption']?.toString() ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Caption'),
        content: TextField(
          controller: captionController,
          decoration: const InputDecoration(
            labelText: 'Caption',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, captionController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _supabase.from('event_photos').update({'caption': result}).eq('id', photo['id']);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
        }
      }
    }
  }

  void _viewPhoto(Map<String, dynamic> photo) {
    final url = photo['photo_url']?.toString() ?? '';
    if (url.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewerPage(
          photoUrl: url,
          caption: photo['caption']?.toString() ?? '',
          uploadedAt: photo['uploaded_at'],
          agentName: (photo['users'] as Map<String, dynamic>?)?['full_name']?.toString() ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Photos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (ctx, i) {
                    final p = _photos[i];
                    final url = p['photo_url'] ?? '';
                    return GestureDetector(
                      onTap: () => _viewPhoto(p),
                      onLongPress: () => _showPhotoOptions(p),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: url.isEmpty
                            ? const Card(child: Center(child: Icon(Icons.image)))
                            : Image.network(url, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'gallery',
            onPressed: _uploadFromGallery,
            tooltip: 'From Gallery',
            child: const Icon(Icons.photo_library),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'camera',
            onPressed: _uploadPhoto,
            tooltip: 'Take Photo',
            child: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions(Map<String, dynamic> photo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Caption'),
              onTap: () {
                Navigator.pop(ctx);
                _editCaption(photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deletePhoto(photo);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No photos yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the camera button to add photos',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _PhotoViewerPage extends StatelessWidget {
  final String photoUrl;
  final String caption;
  final dynamic uploadedAt;
  final String agentName;

  const _PhotoViewerPage({
    required this.photoUrl,
    required this.caption,
    this.uploadedAt,
    required this.agentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Photo', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.network(photoUrl, fit: BoxFit.contain),
            ),
          ),
          if (caption.isNotEmpty || agentName.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black87,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (caption.isNotEmpty)
                    Text(caption, style: const TextStyle(color: Colors.white)),
                  if (agentName.isNotEmpty)
                    Text('By: $agentName', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  if (uploadedAt != null)
                    Text(
                      EventDateFormat.format(uploadedAt),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
