import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_channel.dart';

class LiveChannelService {
  static const String _channelsKey = 'live_channels';
  static const String _sourceUrlKey = 'live_source_url';
  static const String _favoritesKey = 'live_favorites';
  static const String _customUAKey = 'live_custom_ua';

  // 获取频道列表
  static Future<List<LiveChannel>> getChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final channelsJson = prefs.getString(_channelsKey);
    
    if (channelsJson == null || channelsJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = json.decode(channelsJson);
      final channels = decoded.map((e) => LiveChannel.fromJson(e)).toList();
      
      // 加载收藏状态
      final favorites = await _getFavoriteIds();
      for (var channel in channels) {
        channel.isFavorite = favorites.contains(channel.id);
      }
      
      return channels;
    } catch (e) {
      print('解析频道列表失败: $e');
      return [];
    }
  }

  // 保存频道列表
  static Future<void> saveChannels(List<LiveChannel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final channelsJson = json.encode(channels.map((e) => e.toJson()).toList());
    await prefs.setString(_channelsKey, channelsJson);
  }

  // 获取频道源地址
  static Future<String?> getSourceUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sourceUrlKey);
  }

  // 保存频道源地址
  static Future<void> saveSourceUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sourceUrlKey, url);
  }

  // 从URL导入频道
  static Future<List<LiveChannel>> importFromUrl(String url, {String? customUA}) async {
    try {
      final headers = <String, String>{};
      
      // 如果提供了自定义 UA，使用它；否则使用保存的 UA
      final ua = customUA ?? await getCustomUA();
      if (ua != null && ua.isNotEmpty) {
        headers['User-Agent'] = ua;
      }
      
      final response = await http.get(Uri.parse(url), headers: headers);
      
      if (response.statusCode != 200) {
        throw Exception('请求失败: ${response.statusCode}');
      }

      final content = utf8.decode(response.bodyBytes);
      final channels = _parseChannels(content);
      
      if (channels.isEmpty) {
        throw Exception('未找到有效频道');
      }

      await saveChannels(channels);
      await saveSourceUrl(url);
      
      // 如果提供了自定义 UA，保存它
      if (customUA != null && customUA.isNotEmpty) {
        await saveCustomUA(customUA);
      }
      
      return channels;
    } catch (e) {
      throw Exception('导入失败: $e');
    }
  }

  // 解析频道内容（支持 m3u 和 txt 格式）
  static List<LiveChannel> _parseChannels(String content) {
    if (content.trim().startsWith('#EXTM3U')) {
      return _parseM3u(content);
    } else if (content.trim().startsWith('[')) {
      return _parseJson(content);
    } else {
      return _parseTxt(content);
    }
  }

  // 解析 M3U 格式
  static List<LiveChannel> _parseM3u(String content) {
    final lines = content.split('\n');
    final channels = <LiveChannel>[];
    final channelMap = <String, List<LiveChannel>>{};
    
    LiveChannel? currentChannel;
    int id = 0;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('#EXTINF')) {
        final nameMatch = RegExp(r'tvg-name="([^"]+)"').firstMatch(trimmed);
        final logoMatch = RegExp(r'tvg-logo="([^"]+)"').firstMatch(trimmed);
        final numMatch = RegExp(r'tvg-chno="([^"]+)"').firstMatch(trimmed);
        final groupMatch = RegExp(r'group-title="([^"]+)"').firstMatch(trimmed);
        
        final parts = trimmed.split(',');
        final title = parts.length > 1 ? parts.last.trim() : '';
        final name = nameMatch?.group(1)?.trim() ?? title;
        
        currentChannel = LiveChannel(
          id: id++,
          name: name,
          title: title,
          logo: logoMatch?.group(1)?.trim() ?? '',
          uris: [],
          group: groupMatch?.group(1)?.trim() ?? '未分组',
          number: int.tryParse(numMatch?.group(1)?.trim() ?? '') ?? -1,
        );
      } else if (!trimmed.startsWith('#') && currentChannel != null) {
        final key = '${currentChannel.group}_${currentChannel.name}';
        if (!channelMap.containsKey(key)) {
          channelMap[key] = [currentChannel];
        }
        channelMap[key]!.last.uris.add(trimmed);
      }
    }

    // 合并相同频道的多个源
    for (var entry in channelMap.entries) {
      final allUris = entry.value.expand((c) => c.uris).toList();
      final channel = entry.value.first.copyWith(uris: allUris);
      channels.add(channel);
    }

    return channels;
  }

  // 解析 TXT 格式
  static List<LiveChannel> _parseTxt(String content) {
    final lines = content.split('\n');
    final channels = <LiveChannel>[];
    final channelMap = <String, List<String>>{};
    String currentGroup = '未分组';
    int id = 0;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.contains('#genre#')) {
        currentGroup = trimmed.split(',').first.trim();
      } else if (trimmed.contains(',')) {
        final parts = trimmed.split(',');
        final title = parts.first.trim();
        final uris = parts.skip(1).map((e) => e.trim()).toList();
        
        final key = '${currentGroup}_$title';
        if (!channelMap.containsKey(key)) {
          channelMap[key] = [];
        }
        channelMap[key]!.addAll(uris);
      }
    }

    for (var entry in channelMap.entries) {
      final parts = entry.key.split('_');
      final group = parts.first;
      final title = parts.skip(1).join('_');
      
      channels.add(LiveChannel(
        id: id++,
        name: title,
        title: title,
        logo: '',
        uris: entry.value,
        group: group,
      ));
    }

    return channels;
  }

  // 解析 JSON 格式
  static List<LiveChannel> _parseJson(String content) {
    try {
      final List<dynamic> decoded = json.decode(content);
      return decoded.asMap().entries.map((entry) {
        final data = entry.value;
        return LiveChannel(
          id: entry.key,
          name: data['name'] ?? '',
          title: data['title'] ?? data['name'] ?? '',
          logo: data['logo'] ?? '',
          uris: List<String>.from(data['uris'] ?? []),
          group: data['group'] ?? '未分组',
          number: data['number'] ?? -1,
          headers: data['headers'] != null
              ? Map<String, String>.from(data['headers'])
              : null,
        );
      }).toList();
    } catch (e) {
      print('解析 JSON 失败: $e');
      return [];
    }
  }

  // 按分组获取频道
  static Future<List<LiveChannelGroup>> getChannelsByGroup() async {
    final channels = await getChannels();
    final groupMap = <String, List<LiveChannel>>{};

    for (var channel in channels) {
      if (!groupMap.containsKey(channel.group)) {
        groupMap[channel.group] = [];
      }
      groupMap[channel.group]!.add(channel);
    }

    return groupMap.entries
        .map((e) => LiveChannelGroup(name: e.key, channels: e.value))
        .toList();
  }

  // 获取收藏的频道ID列表
  static Future<Set<int>> _getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_favoritesKey);
    
    if (favoritesJson == null || favoritesJson.isEmpty) {
      return {};
    }

    try {
      final List<dynamic> decoded = json.decode(favoritesJson);
      return decoded.map((e) => e as int).toSet();
    } catch (e) {
      return {};
    }
  }

  // 保存收藏的频道ID列表
  static Future<void> _saveFavoriteIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesKey, json.encode(ids.toList()));
  }

  // 切换收藏状态
  static Future<void> toggleFavorite(int channelId) async {
    final favorites = await _getFavoriteIds();
    
    if (favorites.contains(channelId)) {
      favorites.remove(channelId);
    } else {
      favorites.add(channelId);
    }
    
    await _saveFavoriteIds(favorites);
  }

  // 获取收藏的频道
  static Future<List<LiveChannel>> getFavoriteChannels() async {
    final channels = await getChannels();
    return channels.where((c) => c.isFavorite).toList();
  }

  // 获取自定义 UA
  static Future<String?> getCustomUA() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customUAKey);
  }

  // 保存自定义 UA
  static Future<void> saveCustomUA(String ua) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customUAKey, ua);
  }

  // 清除自定义 UA
  static Future<void> clearCustomUA() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customUAKey);
  }
}
