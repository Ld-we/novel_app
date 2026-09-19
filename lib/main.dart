import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_links/app_links.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NovelApp());
}



// رابط السيرفر المحدث
const String baseUrl = 'https://citizenship-rouge-naval-elegant.trycloudflare.com';

class NovelApp extends StatelessWidget {
  const NovelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'رواياتي الحصرية',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const NovelsHomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/add_novel': (context) => const AddNovelScreen(),
      },
    );
  }
}

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}

// ================= الشاشة الرئيسية =================
class NovelsHomeScreen extends StatefulWidget {
  const NovelsHomeScreen({super.key});

  @override
  State<NovelsHomeScreen> createState() => _NovelsHomeScreenState();
}

class _NovelsHomeScreenState extends State<NovelsHomeScreen> {
  late AppLinks _appLinks;
  List novels = [];
  bool isLoading = true;
  String errorMessage = '';
  bool isAdmin = false;
  String username = 'زائر';

  @override
  void initState() {
    super.initState();
    loadUserData();
    fetchNovels();
    initDeepLinks();
  }

  void initDeepLinks() async {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) {
      handleIncomingUri(uri);
    });
  }

  void handleIncomingUri(Uri uri) {
    if (uri.pathSegments.contains('novel')) {
      String? novelId = uri.queryParameters['id'];
      if (novelId != null) {
        print("تم فتح الرواية رقم: $novelId عبر الرابط العميق!");
      }
    }
  }

  Future<void> loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isAdmin = prefs.getBool('is_admin') ?? false;
      username = prefs.getString('username') ?? 'زائر';
    });
  }

  Future<void> fetchNovels() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/novel_app/api/get_novels.php'));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() {
          if (decodedData is List) {
            novels = decodedData;
          } else if (decodedData is Map && decodedData.containsKey('data')) {
            novels = decodedData['data'];
          } else {
            novels = [];
          }
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'خطأ من السيرفر: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'فشل الاتصال بالسيرفر:\n$e';
        isLoading = false;
      });
    }
  }

  Future<void> deleteNovel(String novelId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/novel_app/api/delete_novel.php'),
        body: {'id': novelId},
      );
      fetchNovels();
    } catch (e) {}
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      isAdmin = false;
      username = 'زائر';
    });
    fetchNovels();
  }

  Future<void> _launchInstagram() async {
    final Uri url = Uri.parse('https://www.instagram.com/noura.writer?stkn=MWRtY2lhaGR3MXAwOA==');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مرحباً, $username'),
        backgroundColor: const Color(0xFF0F3460),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_box, color: Colors.amber),
              onPressed: () => Navigator.pushNamed(context, '/add_novel').then((_) => fetchNovels()),
              tooltip: 'إضافة رواية',
            ),
          if (username == 'زائر')
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: () => Navigator.pushNamed(context, '/login').then((_) => loadUserData()),
              tooltip: 'تسجيل دخول',
            )
          else
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: logout,
              tooltip: 'تسجيل خروج',
            ),
        ],
      ),
      body: AppBackground(
        child: Column(
          children: [
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : errorMessage.isNotEmpty
                      ? Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red)))
                      : ListView.builder(
                          itemCount: novels.length,
                          itemBuilder: (context, index) {
                            final novel = novels[index];
                            return Card(
                              color: Colors.white.withOpacity(0.05),
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: novel['image'] != null && novel['image'].toString().isNotEmpty
                                    ? Image.network(
                                        '$baseUrl/novel_app/uploads/${novel['image']}',
                                        width: 50, height: 50, fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.book, color: Colors.white),
                                      )
                                    : const Icon(Icons.book, color: Colors.white),
                                title: Text(novel['title'] ?? 'بدون عنوان', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(novel['description'] ?? '', maxLines: 1, style: const TextStyle(color: Colors.white70)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('حذف الرواية'),
                                              content: const Text('هل أنت متأكد من حذف هذه الرواية؟'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    deleteNovel(novel['novel_id']?.toString() ?? novel['id'].toString());
                                                  },
                                                  child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NovelDetailScreen(novel: novel),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: const Color(0xFF0F3460).withOpacity(0.85),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _launchInstagram,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/e/e7/Instagram_logo_2016.svg',
                          width: 20,
                          height: 20,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.camera_alt, color: Colors.pinkAccent, size: 20),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'حسابي الرسمي على إنستغرام',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'جميع الحقوق محفوظة © 2026',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= شاشة تفاصيل الرواية =================
class NovelDetailScreen extends StatefulWidget {
  final Map novel;
  const NovelDetailScreen({super.key, required this.novel});

  @override
  _NovelDetailScreenState createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  final _commentController = TextEditingController();
  List comments = [];
  List chapters = [];
  bool isLoadingChapters = true;
  bool isLoadingComments = true;
  String? replyingToCommentId;
  String? replyingToUser;
  
  double _fontSize = 16.0; 
  int _savedParagraphIndex = -1;

  @override
  void initState() {
    super.initState();
    fetchChapters();
    fetchComments();
    loadBookmark();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _shareNovel() {
    String novelId = widget.novel['novel_id']?.toString() ?? widget.novel['id']?.toString() ?? '';
    String novelTitle = widget.novel['title'] ?? 'رواية حصرية';
    String shareUrl = '$baseUrl/novel_app/novel.php?id=$novelId';
    Share.share('اقرأ معنا رواية "$novelTitle" حصرياً عبر الرابط:\n$shareUrl');
  }

  Future<void> loadBookmark() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String novelId = widget.novel['novel_id']?.toString() ?? widget.novel['id']?.toString() ?? '';
    setState(() {
      _savedParagraphIndex = prefs.getInt('bookmark_$novelId') ?? -1;
    });
  }

  Future<void> saveBookmark(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String novelId = widget.novel['novel_id']?.toString() ?? widget.novel['id']?.toString() ?? '';
    await prefs.setInt('bookmark_$novelId', index);
    setState(() {
      _savedParagraphIndex = index;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ مكان التوقف بنجاح!'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> fetchChapters() async {
    String novelId = widget.novel['novel_id']?.toString() ?? widget.novel['id']?.toString() ?? '';
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/novel_app/api/get_chapters.php?novel_id=$novelId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          chapters = data is List ? data : [];
          isLoadingChapters = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingChapters = false;
      });
    }
  }

  Future<void> fetchComments() async {
    String novelId = widget.novel['novel_id']?.toString() ?? widget.novel['id']?.toString() ?? '';
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/novel_app/api/get_comments.php?novel_id=$novelId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          comments = json.decode(response.body);
          isLoadingComments = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingComments = false;
      });
    }
  }

  Future<void> addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userName = prefs.getString('username') ?? 'زائر';
    String novelId = widget.novel['novel_id']?.toString() ?? widget.novel['id']?.toString() ?? '';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/novel_app/api/add_comment.php'),
        body: {
          'novel_id': novelId,
          'username': userName,
          'comment': _commentController.text.trim(),
          'parent_id': replyingToCommentId ?? '0',
        },
      );

      if (response.statusCode == 200) {
        _commentController.clear();
        setState(() {
          replyingToCommentId = null;
          replyingToUser = null;
        });
        fetchComments();
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    String fullContent = widget.novel['description'] ?? 'لا يوجد محتوى';
    List<String> paragraphs = fullContent.split('\n');
    bool hasChapters = chapters.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel['title'] ?? 'تفاصيل الرواية'),
        backgroundColor: const Color(0xFF0F3460),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.amber),
            tooltip: 'مشاركة الرواية',
            onPressed: _shareNovel,
          ),
          if (!hasChapters) ...[
            IconButton(
              icon: const Icon(Icons.text_increase),
              tooltip: 'تكبير الخط',
              onPressed: () => setState(() { if (_fontSize < 28) _fontSize += 2; }),
            ),
            IconButton(
              icon: const Icon(Icons.text_decrease),
              tooltip: 'تصغير الخط',
              onPressed: () => setState(() { if (_fontSize > 12) _fontSize -= 2; }),
            ),
          ]
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (widget.novel['image'] != null && widget.novel['image'].toString().isNotEmpty)
              Center(
                child: Image.network(
                  '$baseUrl/novel_app/uploads/${widget.novel['image']}',
                  height: 180, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
              ),
            const SizedBox(height: 15),
            Text(widget.novel['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
            const Divider(color: Colors.white24, height: 25),

            if (isLoadingChapters)
              const Center(child: CircularProgressIndicator())
            else if (hasChapters) ...[
              const Text('فصول الرواية:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  return Card(
                    color: Colors.white.withOpacity(0.08),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(chapter['chapter_title'] ?? 'الفصل ${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChapterReadScreen(chapter: chapter),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ] else ...[
              const Text('نص الرواية (اضغط على أي فقرة لحفظ مكان توقفك):', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 10),
              ...List.generate(paragraphs.length, (index) {
                bool isBookmarked = _savedParagraphIndex == index;
                return GestureDetector(
                  onTap: () => saveBookmark(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isBookmarked ? Colors.amber.withOpacity(0.2) : Colors.transparent,
                      border: Border.all(color: isBookmarked ? Colors.amber : Colors.transparent),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isBookmarked)
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(Icons.bookmark, color: Colors.amber, size: 20),
                          ),
                        Expanded(
                          child: Text(
                            paragraphs[index],
                            style: TextStyle(fontSize: _fontSize, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],

            const Divider(color: Colors.white24, height: 40),
            const Text('التعليقات:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            
            isLoadingComments
                ? const Center(child: CircularProgressIndicator())
                : comments.isEmpty
                    ? const Text('لا توجد تعليقات بعد. كن أول من يعلق!', style: TextStyle(color: Colors.white54))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          bool isReply = comment['parent_id'] != null && comment['parent_id'].toString() != '0';
                          return Container(
                            margin: EdgeInsets.only(left: isReply ? 30.0 : 0.0, top: 4, bottom: 4),
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(comment['username'] ?? 'مستخدم', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          replyingToCommentId = comment['id'].toString();
                                          replyingToUser = comment['username'];
                                        });
                                      },
                                      child: const Text('رد', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    ),
                                  ],
                                ),
                                Text(comment['comment'] ?? '', style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          );
                        },
                      ),
            
            const SizedBox(height: 15),
            if (replyingToUser != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الرد على: $replyingToUser', style: const TextStyle(color: Colors.amber, fontSize: 12)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                    onPressed: () {
                      setState(() {
                        replyingToCommentId = null;
                        replyingToUser = null;
                      });
                    },
                  ),
                ],
              ),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: replyingToUser != null ? 'اكتب ردك...' : 'اكتب تعليقك...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.amber),
                  onPressed: addComment,
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ================= شاشة قراءة الفصل المنفصل =================
class ChapterReadScreen extends StatefulWidget {
  final Map chapter;
  const ChapterReadScreen({super.key, required this.chapter});

  @override
  _ChapterReadScreenState createState() => _ChapterReadScreenState();
}

class _ChapterReadScreenState extends State<ChapterReadScreen> {
  double _fontSize = 16.0;
  int _savedParagraphIndex = -1;

  @override
  void initState() {
    super.initState();
    loadBookmark();
  }

  Future<void> loadBookmark() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String chapterId = widget.chapter['chapter_id']?.toString() ?? widget.chapter['id']?.toString() ?? '';
    setState(() {
      _savedParagraphIndex = prefs.getInt('chapter_bookmark_$chapterId') ?? -1;
    });
  }

  Future<void> saveBookmark(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String chapterId = widget.chapter['chapter_id']?.toString() ?? widget.chapter['id']?.toString() ?? '';
    await prefs.setInt('chapter_bookmark_$chapterId', index);
    setState(() {
      _savedParagraphIndex = index;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ مكان التوقف في الفصل!'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    String content = widget.chapter['content'] ?? 'لا يوجد محتوى لهذا الفصل';
    List<String> paragraphs = content.split('\n');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chapter['chapter_title'] ?? 'قراءة الفصل'),
        backgroundColor: const Color(0xFF0F3460),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_increase),
            tooltip: 'تكبير الخط',
            onPressed: () => setState(() { if (_fontSize < 28) _fontSize += 2; }),
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease),
            tooltip: 'تصغير الخط',
            onPressed: () => setState(() { if (_fontSize > 12) _fontSize -= 2; }),
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('اضغط على أي فقرة لحفظ مكان توقفك:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            ...List.generate(paragraphs.length, (index) {
              bool isBookmarked = _savedParagraphIndex == index;
              return GestureDetector(
                onTap: () => saveBookmark(index),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isBookmarked ? Colors.amber.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(color: isBookmarked ? Colors.amber : Colors.transparent),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isBookmarked)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.bookmark, color: Colors.amber, size: 20),
                        ),
                      Expanded(
                        child: Text(
                          paragraphs[index],
                          style: TextStyle(fontSize: _fontSize, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ================= شاشة تسجيل الدخول =================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = '';

  void _login() async {
    String u = _usernameController.text.trim();
    String p = _passwordController.text.trim();

    if (u == 'admin' && p == '123456') {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_admin', true);
      await prefs.setString('username', 'المشرف (Admin)');
      Navigator.pop(context);
    } else {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/novel_app/api/login.php'),
          body: {'username': u, 'password': p},
        );
        if (response.statusCode == 200) {
          final res = json.decode(response.body);
          if (res['status'] == 'success') {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_admin', false);
            await prefs.setString('username', u);
            Navigator.pop(context);
            return;
          }
        }
      } catch (e) {}

      setState(() {
        _errorMessage = 'اسم المستخدم أو كلمة المرور غير صحيحة';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول'), backgroundColor: const Color(0xFF0F3460)),
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(controller: _usernameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'اسم المستخدم', labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: _passwordController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'كلمة المرور', labelStyle: TextStyle(color: Colors.white70))),
              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty) Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
              ElevatedButton(onPressed: _login, child: const Text('دخول')),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                child: const Text('ليس لديك حساب؟ سجل الآن', style: TextStyle(color: Colors.amber)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= شاشة تسجيل حساب جديد =================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _message = '';

  void _register() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/novel_app/api/register.php'),
        body: {
          'username': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        setState(() {
          _message = res['message'];
        });
        if (res['status'] == 'success') {
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pushReplacementNamed(context, '/login');
          });
        }
      }
    } catch (e) {
      setState(() {
        _message = 'فشل الاتصال بالسيرفر';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل حساب جديد'), backgroundColor: const Color(0xFF0F3460)),
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(controller: _usernameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'اسم المستخدم الجديد', labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: _passwordController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'كلمة المرور', labelStyle: TextStyle(color: Colors.white70))),
              const SizedBox(height: 20),
              if (_message.isNotEmpty) Text(_message, style: const TextStyle(color: Colors.amber)),
              ElevatedButton(onPressed: _register, child: const Text('إنشاء الحساب')),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('لديك حساب بالفعل؟ سجل دخولك', style: TextStyle(color: Colors.amber)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= شاشة إضافة رواية =================
class AddNovelScreen extends StatefulWidget {
  const AddNovelScreen({super.key});

  @override
  _AddNovelScreenState createState() => _AddNovelScreenState();
}

class _AddNovelScreenState extends State<AddNovelScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;
  String _statusMessage = '';

  final List<Map<String, TextEditingController>> _chaptersList = [];

  void _addChapterField() {
    setState(() {
      _chaptersList.add({
        'title': TextEditingController(text: 'الفصل ${_chaptersList.length + 1}'),
        'content': TextEditingController(),
      });
    });
  }

  void _removeChapterField(int index) {
    setState(() {
      _chaptersList[index]['title']?.dispose();
      _chaptersList[index]['content']?.dispose();
      _chaptersList.removeAt(index);
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadNovel() async {
    setState(() {
      _isUploading = true;
      _statusMessage = '';
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/novel_app/api/add_novel.php'),
      );
      request.fields['title'] = _titleController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();

      if (_chaptersList.isNotEmpty) {
        List<Map<String, String>> formattedChapters = _chaptersList.map((ch) => {
          'chapter_title': ch['title']!.text.trim(),
          'content': ch['content']!.text.trim(),
        }).toList();
        request.fields['chapters'] = json.encode(formattedChapters);
      }

      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _selectedImage!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = 'تم نشر الرواية بنجاح!';
          _isUploading = false;
          _titleController.clear();
          _descriptionController.clear();
          _selectedImage = null;
          _chaptersList.clear();
        });
      } else {
        setState(() {
          _statusMessage = 'خطأ في السيرفر: ${response.statusCode}';
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'فشل الاتصال: $e';
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة رواية جديدة'), backgroundColor: const Color(0xFF0F3460)),
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'عنوان الرواية',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'وصف أو نبذة عن الرواية',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 15),
              _selectedImage != null
                  ? Image.file(_selectedImage!, height: 120, fit: BoxFit.cover)
                  : Container(
                      height: 120,
                      color: Colors.white10,
                      child: const Center(
                        child: Text(
                          'لا توجد صورة مختارة',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('اختر صورة'),
              ),
              const Divider(color: Colors.white24, height: 30),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إضافة فصول (اختياري):', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                  ElevatedButton.icon(
                    onPressed: _addChapterField,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة فصل'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  ),
                ],
              ),
              const Text('إذا أضفت فصولاً، سيتم عرضها كفصول منفصلة. إذا تركتها فارغة، ستكون الرواية بنص كامل مباشر.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 10),

              ...List.generate(_chaptersList.length, (index) {
                return Card(
                  color: Colors.white.withOpacity(0.05),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _chaptersList[index]['title'],
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(labelText: 'عنوان الفصل', labelStyle: TextStyle(color: Colors.white70)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _removeChapterField(index),
                            ),
                          ],
                        ),
                        TextField(
                          controller: _chaptersList[index]['content'],
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'محتوى الفصل', labelStyle: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),
              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.contains('نجاح')
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ),
              _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _uploadNovel,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                      child: const Text('نشر الرواية', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
