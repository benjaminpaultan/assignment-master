import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// --- DATA MODEL ---
class Guide {
  final int id;
  final String userId;
  final String? username;
  final String title;
  final String category;
  final String content;
  final String? fileUrl;
  final DateTime createdAt;
  final int commentCount;
  bool isLiked;
  bool isFavorited;
  int likeCount;

  Guide({
    required this.id, required this.userId, this.username,
    required this.title, required this.category,
    required this.content, this.fileUrl, required this.createdAt,
    required this.commentCount,
    this.isLiked = false, this.isFavorited = false, this.likeCount = 0,
  });

  bool get isYoutube => fileUrl?.contains('youtube.com') ?? fileUrl?.contains('youtu.be') ?? false;
  bool get isVideo => (fileUrl?.toLowerCase().endsWith('.mp4') ?? false) || isYoutube;

  factory Guide.fromJson(Map<String, dynamic> json, String currentUserId) {
    final likes = json['guide_likes'] as List? ?? [];
    final favorites = json['guide_favorites'] as List? ?? [];
    final comments = json['guide_comments'] as List? ?? [];

    final profile = json['profiles'] as Map<String, dynamic>?;
    final name = profile?['username'];

    return Guide(
      id: json['id'],
      userId: json['user_id'] ?? '',
      username: name,
      title: json['title'] ?? 'No Title',
      category: json['category'] ?? 'General',
      content: json['content'] ?? '',
      fileUrl: json['file_url'],
      createdAt: DateTime.parse(json['created_at']),
      commentCount: comments.length,
      likeCount: likes.length,
      isLiked: likes.any((l) => l['user_id'] == currentUserId),
      isFavorited: favorites.any((f) => f['user_id'] == currentUserId),
    );
  }
}

class GuidePage extends StatefulWidget {
  const GuidePage({super.key});
  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  final supabase = Supabase.instance.client;
  List<Guide> allGuides = [];
  List<Guide> filteredGuides = [];
  bool isLoading = true;

  String searchQuery = "";
  String selectedCategory = "All";
  String sortBy = "Newest";
  bool showFavoritesOnly = false;
  final List<String> categories = ["Stress", "Anxiety", "Study-Life", "Motivation", "General"];

  @override
  void initState() {
    super.initState();
    _fetchGuides();
  }

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return "${date.day}/${date.month}/${date.year}";
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }

  Future<void> _fetchGuides() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      // Only show approved guides to regular users (admins see all in their dashboard)
      final response = await supabase
          .from('guides')
          .select('*, profiles!left(username), guide_likes(user_id), guide_favorites(user_id), guide_comments(id)')
          .or('status.is.null,status.eq.approved')
          .order('created_at', ascending: false);

      setState(() {
        allGuides = (response as List).map((g) => Guide.fromJson(g, user.id)).toList();
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Error: $e");
      setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredGuides = allGuides.where((g) {
        final matchesSearch = g.title.toLowerCase().contains(searchQuery.toLowerCase());
        final matchesCat = selectedCategory == "All" || g.category == selectedCategory;
        final matchesFav = !showFavoritesOnly || g.isFavorited;
        return matchesSearch && matchesCat && matchesFav;
      }).toList();

      if (sortBy == "Newest") filteredGuides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      else if (sortBy == "Oldest") filteredGuides.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      else if (sortBy == "A-Z") filteredGuides.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    });
  }

  // --- ACTIONS ---
  Future<void> _toggleLike(Guide guide) async {
    final userId = supabase.auth.currentUser!.id;
    if (guide.isLiked) {
      await supabase.from('guide_likes').delete().eq('guide_id', guide.id).eq('user_id', userId);
    } else {
      await supabase.from('guide_likes').insert({'guide_id': guide.id, 'user_id': userId});
    }
    _fetchGuides();
  }

  Future<void> _toggleFavorite(Guide guide) async {
    final userId = supabase.auth.currentUser!.id;
    if (guide.isFavorited) {
      await supabase.from('guide_favorites').delete().eq('guide_id', guide.id).eq('user_id', userId);
    } else {
      await supabase.from('guide_favorites').insert({'guide_id': guide.id, 'user_id': userId});
    }
    _fetchGuides();
  }

  Future<void> _deletePost(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Post?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.from('guides').delete().eq('id', id);
      _fetchGuides();
    }
  }

  void _showEditForm(Guide guide) {
    final titleCtrl = TextEditingController(text: guide.title);
    final contentCtrl = TextEditingController(text: guide.content);
    String editCat = guide.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Post", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
            DropdownButtonFormField<String>(
              value: editCat, items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => editCat = v!,
            ),
            TextField(controller: contentCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Description")),
            const SizedBox(height: 15),
            ElevatedButton(onPressed: () async {
              await supabase.from('guides').update({
                'title': titleCtrl.text,
                'category': editCat,
                'content': contentCtrl.text,
              }).eq('id', guide.id);
              Navigator.pop(context);
              _fetchGuides();
            }, child: const Text("Update")),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showUploadForm() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String uploadCat = "General";
    PlatformFile? pickedFile;
    bool isUrlMode = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Create Post", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Upload"), Switch(value: isUrlMode, onChanged: (v) => setModalState(() => isUrlMode = v)), const Text("URL"),
              ]),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
              DropdownButtonFormField<String>(
                value: uploadCat, items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => uploadCat = v!,
              ),
              if (isUrlMode) TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "Link"))
              else ListTile(leading: const Icon(Icons.attach_file), title: Text(pickedFile?.name ?? "Pick Media"), onTap: () async {
                final res = await FilePicker.platform.pickFiles(type: FileType.media);
                if (res != null) setModalState(() => pickedFile = res.files.first);
              }),
              TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: "Description")),
              ElevatedButton(onPressed: () async {
                Navigator.pop(context);
                setState(() => isLoading = true);
                String? finalUrl = urlCtrl.text.trim();
                if (!isUrlMode && pickedFile != null) {
                  final name = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile!.name}';
                  await supabase.storage.from('wellness_files').upload(name, File(pickedFile!.path!));
                  finalUrl = supabase.storage.from('wellness_files').getPublicUrl(name);
                }
                await supabase.from('guides').insert({
                  'title': titleCtrl.text,
                  'category': uploadCat,
                  'content': contentCtrl.text,
                  'file_url': finalUrl,
                  'user_id': supabase.auth.currentUser!.id,
                  'status': 'pending', // Default to pending for admin approval
                });
                _fetchGuides();
              }, child: const Text("Publish")),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text("Wellness Community"), actions: [
        IconButton(
            icon: Icon(showFavoritesOnly ? Icons.bookmark : Icons.bookmark_border,
                color: showFavoritesOnly ? Colors.amber : null),
            onPressed: () { setState(() => showFavoritesOnly = !showFavoritesOnly); _applyFilters(); }),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _showUploadForm, child: const Icon(Icons.add)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextField(
                decoration: InputDecoration(hintText: "Search...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onChanged: (v) { searchQuery = v; _applyFilters(); },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: DropdownButton<String>(value: selectedCategory, isExpanded: true, items: ["All", ...categories].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { setState(() => selectedCategory = v!); _applyFilters(); })),
                const SizedBox(width: 10),
                Expanded(child: DropdownButton<String>(value: sortBy, isExpanded: true, items: ["Newest", "Oldest", "A-Z"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) { setState(() => sortBy = v!); _applyFilters(); })),
              ]),
            ]),
          ),
          Expanded(
            child: isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: filteredGuides.length,
              itemBuilder: (context, i) {
                final g = filteredGuides[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(children: [
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("By ${g.username ?? g.userId.substring(0, 8)} • ${_formatRelativeTime(g.createdAt)}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // RESTORED: Favorite Button
                          IconButton(
                              icon: Icon(g.isFavorited ? Icons.bookmark : Icons.bookmark_border, color: Colors.amber),
                              onPressed: () => _toggleFavorite(g)
                          ),
                          // RESTORED: Edit/Delete only for owner
                          if (g.userId == myId) ...[
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditForm(g)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deletePost(g.id)),
                          ]
                        ],
                      ),
                    ),
                    if (g.fileUrl != null)
                      GestureDetector(
                        onTap: () async {
                          // Navigate and refresh when returning
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (c) => GuideDetailPage(guide: g)),
                          );
                          // Refresh guides list when returning to update comment counts
                          _fetchGuides();
                        },
                        child: Container(
                          height: 180, width: double.infinity, color: Colors.black12,
                          child: g.isVideo ? const Icon(Icons.play_circle_fill, size: 50, color: Colors.deepPurple) : Image.network(g.fileUrl!, fit: BoxFit.cover),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        IconButton(icon: Icon(g.isLiked ? Icons.favorite : Icons.favorite_border, color: Colors.red), onPressed: () => _toggleLike(g)),
                        Text("${g.likeCount}"),
                        const SizedBox(width: 15),
                        const Icon(Icons.comment_outlined, size: 20, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text("${g.commentCount}"),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            // Navigate and refresh when returning
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (c) => GuideDetailPage(guide: g)),
                            );
                            // Refresh guides list when returning to update comment counts
                            _fetchGuides();
                          },
                          child: const Text("View Details"),
                        ),
                      ]),
                    )
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- DETAIL & COMMENT PAGE ---
class GuideDetailPage extends StatefulWidget {
  final Guide guide;
  const GuideDetailPage({super.key, required this.guide});
  @override
  State<GuideDetailPage> createState() => _GuideDetailPageState();
}

class _GuideDetailPageState extends State<GuideDetailPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _commentCtrl = TextEditingController();
  List<dynamic> comments = [];
  bool loading = true;
  VideoPlayerController? _v;
  YoutubePlayerController? _y;
  int commentCount = 0; // Track comment count locally

  @override
  void initState() {
    super.initState();
    commentCount = widget.guide.commentCount; // Initialize with guide's count
    _fetchComments();
    _initMedia();
  }

  void _initMedia() {
    String? url = widget.guide.fileUrl;
    if (url == null || url.isEmpty) return;
    if (widget.guide.isYoutube) {
      String? videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) _y = YoutubePlayerController(initialVideoId: videoId, flags: const YoutubePlayerFlags(autoPlay: false));
    } else if (widget.guide.isVideo) {
      _v = VideoPlayerController.networkUrl(Uri.parse(url))..initialize().then((_) => setState(() {}));
    }
  }

  Future<void> _fetchComments() async {
    setState(() => loading = true);
    final res = await supabase.from('guide_comments').select('*, profiles(username)').eq('guide_id', widget.guide.id).order('created_at', ascending: true);
    setState(() {
      comments = res as List;
      commentCount = comments.length; // Update comment count immediately
      loading = false;
    });
  }

  Future<void> _postComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    
    // Optimistically update UI
    setState(() {
      commentCount++; // Increment immediately
    });
    
    try {
      await supabase.from('guide_comments').insert({
        'guide_id': widget.guide.id,
        'user_id': supabase.auth.currentUser!.id,
        'content': _commentCtrl.text.trim()
      });
      _commentCtrl.clear();
      // Refresh comments to get the actual data
      await _fetchComments();
    } catch (e) {
      // If error, revert the optimistic update
      setState(() {
        commentCount--;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  @override
  void dispose() { _v?.dispose(); _y?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.guide.title)),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(child: Column(children: [
          if (widget.guide.fileUrl != null)
            widget.guide.isYoutube
                ? (_y != null ? YoutubePlayer(controller: _y!) : const Text("Video Error"))
                : widget.guide.isVideo
                ? (_v != null && _v!.value.isInitialized ? AspectRatio(aspectRatio: _v!.value.aspectRatio, child: VideoPlayer(_v!)) : const CircularProgressIndicator())
                : Image.network(widget.guide.fileUrl!),
          Padding(padding: const EdgeInsets.all(16), child: Text(widget.guide.content, style: const TextStyle(fontSize: 16))),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  "($commentCount)",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          loading ? const CircularProgressIndicator() : ListView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length, itemBuilder: (context, i) {
            final c = comments[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(c['profiles']['username'] ?? 'User'),
              subtitle: Text(c['content']),
            );
          }),
        ]))),
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(controller: _commentCtrl, decoration: const InputDecoration(hintText: "Add comment...", border: OutlineInputBorder()))),
          IconButton(icon: const Icon(Icons.send, color: Colors.deepPurple), onPressed: _postComment),
        ])),
      ]),
    );
  }
}

