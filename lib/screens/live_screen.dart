import 'package:flutter/material.dart';
import '../models/live_channel.dart';
import '../services/live_channel_service.dart';
import '../utils/font_utils.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart';
import 'live_player_screen.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<LiveChannelGroup> _channelGroups = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedGroup = '全部';
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _uaController = TextEditingController();
  String? _currentUA;

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _loadCustomUA();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _uaController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomUA() async {
    final ua = await LiveChannelService.getCustomUA();
    if (mounted) {
      setState(() {
        _currentUA = ua;
        _uaController.text = ua ?? '';
      });
    }
  }

  Future<void> _loadChannels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await LiveChannelService.getChannelsByGroup();
      
      if (mounted) {
        setState(() {
          _channelGroups = groups;
          _isLoading = false;
          
          // 如果没有频道，显示导入提示
          if (groups.isEmpty) {
            _errorMessage = '暂无频道，请导入频道源';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importChannels() async {
    final url = _urlController.text.trim();
    
    if (url.isEmpty) {
      _showMessage('请输入频道源地址');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final customUA = _uaController.text.trim();
      await LiveChannelService.importFromUrl(
        url,
        customUA: customUA.isNotEmpty ? customUA : null,
      );
      await _loadChannels();
      await _loadCustomUA();
      
      if (mounted) {
        _showMessage('导入成功');
        Navigator.pop(context); // 关闭导入对话框
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '导入失败: $e';
          _isLoading = false;
        });
        _showMessage('导入失败: $e');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: FontUtils.poppins(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3498DB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showUASettingsDialog() {
    final tempController = TextEditingController(text: _currentUA ?? '');
    
    showDialog(
      context: context,
      builder: (context) => Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return AlertDialog(
            backgroundColor: themeService.isDarkMode
                ? const Color(0xFF1e1e1e)
                : Colors.white,
            title: Text(
              'User-Agent 设置',
              style: FontUtils.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: themeService.isDarkMode
                    ? Colors.white
                    : const Color(0xFF2c3e50),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设置自定义 User-Agent 用于访问直播源',
                  style: FontUtils.poppins(
                    fontSize: 12,
                    color: themeService.isDarkMode
                        ? const Color(0xFF999999)
                        : const Color(0xFF7f8c8d),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tempController,
                  decoration: InputDecoration(
                    hintText: '输入 User-Agent',
                    hintStyle: FontUtils.poppins(
                      color: themeService.isDarkMode
                          ? const Color(0xFF666666)
                          : const Color(0xFF95a5a6),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: FontUtils.poppins(
                    fontSize: 13,
                    color: themeService.isDarkMode
                        ? Colors.white
                        : const Color(0xFF2c3e50),
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 12),
                Text(
                  '常用 UA 示例:',
                  style: FontUtils.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeService.isDarkMode
                        ? Colors.white
                        : const Color(0xFF2c3e50),
                  ),
                ),
                const SizedBox(height: 8),
                _buildUAPreset(
                  'Chrome',
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  tempController,
                  themeService,
                ),
                _buildUAPreset(
                  'Android',
                  'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
                  tempController,
                  themeService,
                ),
                _buildUAPreset(
                  'iOS',
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)',
                  tempController,
                  themeService,
                ),
              ],
            ),
            actions: [
              if (_currentUA != null && _currentUA!.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await LiveChannelService.clearCustomUA();
                    await _loadCustomUA();
                    if (context.mounted) {
                      Navigator.pop(context);
                      _showMessage('已清除自定义 UA');
                    }
                  },
                  child: Text(
                    '清除',
                    style: FontUtils.poppins(
                      color: const Color(0xFFe74c3c),
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '取消',
                  style: FontUtils.poppins(
                    color: themeService.isDarkMode
                        ? const Color(0xFF999999)
                        : const Color(0xFF7f8c8d),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final ua = tempController.text.trim();
                  if (ua.isNotEmpty) {
                    await LiveChannelService.saveCustomUA(ua);
                    await _loadCustomUA();
                    if (context.mounted) {
                      Navigator.pop(context);
                      _showMessage('UA 设置成功');
                    }
                  } else {
                    _showMessage('请输入 User-Agent');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27ae60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '保存',
                  style: FontUtils.poppins(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUAPreset(
    String label,
    String ua,
    TextEditingController controller,
    ThemeService themeService,
  ) {
    return GestureDetector(
      onTap: () {
        controller.text = ua;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: themeService.isDarkMode
              ? const Color(0xFF2a2a2a)
              : const Color(0xFFf5f5f5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: FontUtils.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF27ae60),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ua,
                style: FontUtils.poppins(
                  fontSize: 10,
                  color: themeService.isDarkMode
                      ? const Color(0xFF999999)
                      : const Color(0xFF7f8c8d),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return AlertDialog(
            backgroundColor: themeService.isDarkMode
                ? const Color(0xFF1e1e1e)
                : Colors.white,
            title: Text(
              '导入频道源',
              style: FontUtils.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: themeService.isDarkMode
                    ? Colors.white
                    : const Color(0xFF2c3e50),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '支持 M3U、TXT、JSON 格式',
                    style: FontUtils.poppins(
                      fontSize: 12,
                      color: themeService.isDarkMode
                          ? const Color(0xFF999999)
                          : const Color(0xFF7f8c8d),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: '频道源地址',
                      hintText: '输入频道源地址',
                      hintStyle: FontUtils.poppins(
                        color: themeService.isDarkMode
                            ? const Color(0xFF666666)
                            : const Color(0xFF95a5a6),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: FontUtils.poppins(
                      color: themeService.isDarkMode
                          ? Colors.white
                          : const Color(0xFF2c3e50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _uaController,
                    decoration: InputDecoration(
                      labelText: 'User-Agent (可选)',
                      hintText: '自定义 User-Agent',
                      helperText: '某些直播源需要特定的 UA 才能访问',
                      helperStyle: FontUtils.poppins(
                        fontSize: 11,
                        color: themeService.isDarkMode
                            ? const Color(0xFF666666)
                            : const Color(0xFF95a5a6),
                      ),
                      hintStyle: FontUtils.poppins(
                        color: themeService.isDarkMode
                            ? const Color(0xFF666666)
                            : const Color(0xFF95a5a6),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: _uaController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  _uaController.clear();
                                });
                              },
                            )
                          : null,
                    ),
                    style: FontUtils.poppins(
                      fontSize: 13,
                      color: themeService.isDarkMode
                          ? Colors.white
                          : const Color(0xFF2c3e50),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                  if (_currentUA != null && _currentUA!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '当前 UA: $_currentUA',
                      style: FontUtils.poppins(
                        fontSize: 11,
                        color: themeService.isDarkMode
                            ? const Color(0xFF999999)
                            : const Color(0xFF7f8c8d),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '取消',
                  style: FontUtils.poppins(
                    color: themeService.isDarkMode
                        ? const Color(0xFF999999)
                        : const Color(0xFF7f8c8d),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _importChannels,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27ae60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '导入',
                  style: FontUtils.poppins(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<LiveChannel> _getFilteredChannels() {
    if (_selectedGroup == '全部') {
      return _channelGroups.expand((g) => g.channels).toList();
    } else if (_selectedGroup == '收藏') {
      return _channelGroups
          .expand((g) => g.channels)
          .where((c) => c.isFavorite)
          .toList();
    } else {
      return _channelGroups
          .firstWhere((g) => g.name == _selectedGroup,
              orElse: () => LiveChannelGroup(name: '', channels: []))
          .channels;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Column(
          children: [
            // 顶部分组选择和导入按钮
            _buildTopBar(themeService),
            // 频道列表
            Expanded(
              child: _isLoading
                  ? _buildLoadingView(themeService)
                  : _errorMessage != null
                      ? _buildErrorView(themeService)
                      : _buildChannelList(themeService),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(ThemeService themeService) {
    final groups = ['全部', '收藏', ..._channelGroups.map((g) => g.name)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: themeService.isDarkMode
            ? const Color(0xFF1e1e1e).withOpacity(0.9)
            : Colors.white.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: themeService.isDarkMode
                ? const Color(0xFF333333).withOpacity(0.3)
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: groups.map((group) {
                  final isSelected = _selectedGroup == group;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedGroup = group;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF27ae60)
                              : themeService.isDarkMode
                                  ? const Color(0xFF2a2a2a)
                                  : const Color(0xFFf5f5f5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          group,
                          style: FontUtils.poppins(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : themeService.isDarkMode
                                    ? const Color(0xFFb0b0b0)
                                    : const Color(0xFF7f8c8d),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // UA 设置按钮
          if (_currentUA != null && _currentUA!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.settings),
              color: const Color(0xFF3498DB),
              tooltip: '已设置自定义 UA',
              onPressed: _showUASettingsDialog,
            ),
          // 导入按钮
          IconButton(
            icon: const Icon(Icons.add),
            color: const Color(0xFF27ae60),
            onPressed: _showImportDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(ThemeService themeService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF27ae60),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '加载中...',
            style: FontUtils.poppins(
              color: themeService.isDarkMode
                  ? const Color(0xFFb0b0b0)
                  : const Color(0xFF7f8c8d),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeService themeService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: themeService.isDarkMode
                ? const Color(0xFF666666)
                : const Color(0xFF95a5a6),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '加载失败',
            style: FontUtils.poppins(
              color: themeService.isDarkMode
                  ? const Color(0xFFb0b0b0)
                  : const Color(0xFF7f8c8d),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _channelGroups.isEmpty ? _showImportDialog : _loadChannels,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27ae60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _channelGroups.isEmpty ? '导入频道源' : '重试',
              style: FontUtils.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelList(ThemeService themeService) {
    final channels = _getFilteredChannels();

    if (channels.isEmpty) {
      return Center(
        child: Text(
          _selectedGroup == '收藏' ? '暂无收藏频道' : '暂无频道',
          style: FontUtils.poppins(
            color: themeService.isDarkMode
                ? const Color(0xFFb0b0b0)
                : const Color(0xFF7f8c8d),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _buildChannelItem(channel, themeService);
      },
    );
  }

  Widget _buildChannelItem(LiveChannel channel, ThemeService themeService) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LivePlayerScreen(channel: channel),
          ),
        ).then((_) => _loadChannels()); // 返回时刷新收藏状态
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: themeService.isDarkMode
              ? const Color(0xFF1e1e1e)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: themeService.isDarkMode
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 频道图标
            if (channel.logo.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  channel.logo,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildDefaultIcon(themeService);
                  },
                ),
              )
            else
              _buildDefaultIcon(themeService),
            const SizedBox(width: 12),
            // 频道信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.title,
                    style: FontUtils.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: themeService.isDarkMode
                          ? Colors.white
                          : const Color(0xFF2c3e50),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${channel.group} · ${channel.uris.length} 个源',
                    style: FontUtils.poppins(
                      fontSize: 12,
                      color: themeService.isDarkMode
                          ? const Color(0xFF999999)
                          : const Color(0xFF7f8c8d),
                    ),
                  ),
                ],
              ),
            ),
            // 收藏按钮
            IconButton(
              icon: Icon(
                channel.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: channel.isFavorite
                    ? const Color(0xFFe74c3c)
                    : themeService.isDarkMode
                        ? const Color(0xFF666666)
                        : const Color(0xFF95a5a6),
              ),
              onPressed: () async {
                await LiveChannelService.toggleFavorite(channel.id);
                _loadChannels();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(ThemeService themeService) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: themeService.isDarkMode
            ? const Color(0xFF2a2a2a)
            : const Color(0xFFf5f5f5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.tv,
        size: 32,
        color: themeService.isDarkMode
            ? const Color(0xFF666666)
            : const Color(0xFF95a5a6),
      ),
    );
  }
}
