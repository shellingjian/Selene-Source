// 直播频道数据模型
class LiveChannel {
  final int id;
  final String name; // 标准名称
  final String title; // 显示标题
  final String logo; // 频道图标
  final List<String> uris; // 视频源地址列表
  final String group; // 分组名称
  final int number; // 频道号
  final Map<String, String>? headers; // 请求头
  final int videoIndex; // 当前播放的视频源索引
  bool isFavorite; // 是否收藏

  LiveChannel({
    required this.id,
    required this.name,
    required this.title,
    required this.logo,
    required this.uris,
    required this.group,
    this.number = -1,
    this.headers,
    this.videoIndex = 0,
    this.isFavorite = false,
  });

  factory LiveChannel.fromJson(Map<String, dynamic> json) {
    return LiveChannel(
      id: json['id'] ?? -1,
      name: json['name'] ?? '',
      title: json['title'] ?? '',
      logo: json['logo'] ?? '',
      uris: List<String>.from(json['uris'] ?? []),
      group: json['group'] ?? '',
      number: json['number'] ?? -1,
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'])
          : null,
      videoIndex: json['videoIndex'] ?? 0,
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'logo': logo,
      'uris': uris,
      'group': group,
      'number': number,
      'headers': headers,
      'videoIndex': videoIndex,
      'isFavorite': isFavorite,
    };
  }

  LiveChannel copyWith({
    int? id,
    String? name,
    String? title,
    String? logo,
    List<String>? uris,
    String? group,
    int? number,
    Map<String, String>? headers,
    int? videoIndex,
    bool? isFavorite,
  }) {
    return LiveChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      logo: logo ?? this.logo,
      uris: uris ?? this.uris,
      group: group ?? this.group,
      number: number ?? this.number,
      headers: headers ?? this.headers,
      videoIndex: videoIndex ?? this.videoIndex,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

// 直播频道分组
class LiveChannelGroup {
  final String name;
  final List<LiveChannel> channels;

  LiveChannelGroup({
    required this.name,
    required this.channels,
  });
}
