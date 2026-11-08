import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/category.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import 'player_screen.dart';
import 'text_viewer_screen.dart';
import '../services/system_controls_service.dart';

class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final StorageService storageService;

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.storageService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<SeasonCategory> _categories = SeasonCategory.defaultCategories;
  late SeasonCategory _selectedCategory;
  final List<String> _pathHistory = [];
  String _currentPath = '';

  List<FileItem> _items = [];
  List<FileItem> _filteredItems = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categories.first;
    _navigateTo(_selectedCategory.path);
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _currentPath = path;
      _isLoading = true;
      _errorMessage = '';
      _searchQuery = '';
    });

    try {
      final items = await widget.apiService.fetchDirectory(path);
      if (mounted) {
        setState(() {
          _items = items;
          _filteredItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onItemClick(FileItem item) async {
    if (item.isFolder) {
      _pathHistory.add(_currentPath);
      _navigateTo(item.path);
    } else if (item.isVideo) {
      widget.storageService.addHistory(item.name);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: item.name,
            videoUrl: item.url,
          ),
        ),
      );
      SystemControlsService.resetBrightness();
    } else if (item.isText) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TextViewerScreen(
            title: item.name,
            url: item.url,
            apiService: widget.apiService,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已选择: ${item.name}')),
      );
    }
  }

  bool _onWillPop() {
    if (_pathHistory.isNotEmpty) {
      final prevPath = _pathHistory.removeLast();
      _navigateTo(prevPath);
      return false;
    }
    return true;
  }

  void _filterItems(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredItems = _items;
      } else {
        _filteredItems = _items
            .where((i) => i.name.toLowerCase().contains(_searchQuery))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _onWillPop(),
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg(context),
        appBar: AppBar(
          backgroundColor: AppTheme.appBarBg(context),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: _pathHistory.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () => _onWillPop(),
                )
              : null,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: AppTheme.cyanGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.neonGlow(color: AppTheme.electricCyan, opacity: 0.35, blur: 8),
                ),
                child: const Icon(Icons.folder_special_rounded, color: Colors.black, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedCategory.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary(context),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    '纯净无广告资源库',
                    style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted(context)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, color: AppTheme.textSecondary(context)),
              tooltip: _isGridView ? '切换列表' : '切换网格',
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppTheme.textSecondary(context)),
              tooltip: '刷新当前目录',
              onPressed: () => _navigateTo(_currentPath),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            // 1. 季数水平切换滑动栏 (流光胶囊)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: AppTheme.appBarBg(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;
                  return InkWell(
                    onTap: () {
                      if (_selectedCategory != cat) {
                        setState(() {
                          _selectedCategory = cat;
                          _pathHistory.clear();
                        });
                        _navigateTo(cat.path);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppTheme.primaryGradient : null,
                        color: isSelected ? null : AppTheme.chipUnselectedBg(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : AppTheme.borderColor(context),
                          width: 0.8,
                        ),
                        boxShadow: isSelected
                            ? AppTheme.neonGlow(color: AppTheme.primaryPink, opacity: 0.4, blur: 8)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          cat.title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textSecondary(context),
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 2. 搜索框
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              color: AppTheme.appBarBg(context),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.inputBg(context),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: AppTheme.borderColor(context), width: 0.6),
                ),
                child: TextField(
                  style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '搜索当前目录下的视频与文件...',
                    hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryPink, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                  ),
                  onChanged: _filterItems,
                ),
              ),
            ),

            // 3. 面包屑路径条
            if (_currentPath != _selectedCategory.path)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.cardSecondaryBg(context),
                  border: Border(bottom: BorderSide(color: AppTheme.borderColor(context), width: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open_rounded, color: AppTheme.electricCyan, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentPath,
                        style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // 4. 内容展示列表
            Expanded(
              child: _isLoading
                  ? const Center(child: SpinKitFadingCircle(color: AppTheme.primaryPink, size: 40))
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_off_rounded, size: 50, color: AppTheme.textMuted(context)),
                                const SizedBox(height: 12),
                                Text(_errorMessage, style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPink),
                                  onPressed: () => _navigateTo(_currentPath),
                                  child: const Text('重新加载', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filteredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_open_rounded, size: 50, color: AppTheme.textMuted(context)),
                                  const SizedBox(height: 10),
                                  Text('当前文件夹为空', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13)),
                                ],
                              ),
                            )
                          : _isGridView
                              ? GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 90), // 留出底部悬浮岛空间
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 1.1,
                                  ),
                                  itemCount: _filteredItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredItems[index];
                                    return _buildGridTile(item);
                                  },
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 90), // 留出底部悬浮岛空间
                                  itemCount: _filteredItems.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = _filteredItems[index];
                                    return _buildListTile(item);
                                  },
                                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(FileItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.isFolder
                ? AppTheme.electricCyan.withOpacity(0.15)
                : item.isVideo
                    ? AppTheme.primaryPink.withOpacity(0.15)
                    : Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            item.isFolder
                ? Icons.folder_rounded
                : item.isVideo
                    ? Icons.play_circle_fill_rounded
                    : Icons.description_rounded,
            color: item.isFolder
                ? AppTheme.electricCyan
                : item.isVideo
                    ? AppTheme.primaryPink
                    : Colors.amber,
            size: 22,
          ),
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textPrimary(context),
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        subtitle: Text(
          item.isFolder ? '子文件夹' : '${item.size} · ${item.modifiedTime}',
          style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted(context), size: 20),
        onTap: () => _onItemClick(item),
      ),
    );
  }

  Widget _buildGridTile(FileItem item) {
    return InkWell(
      onTap: () => _onItemClick(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
          boxShadow: AppTheme.cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.isFolder
                    ? AppTheme.electricCyan.withOpacity(0.15)
                    : item.isVideo
                        ? AppTheme.primaryPink.withOpacity(0.15)
                        : Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.isFolder
                    ? Icons.folder_rounded
                    : item.isVideo
                        ? Icons.play_circle_fill_rounded
                        : Icons.description_rounded,
                color: item.isFolder
                    ? AppTheme.electricCyan
                    : item.isVideo
                        ? AppTheme.primaryPink
                        : Colors.amber,
                size: 24,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.isFolder ? '文件夹' : item.size,
                  style: TextStyle(color: AppTheme.textMuted(context), fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
