import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../models/model_catalog.dart';

part 'model_catalog_cache.g.dart';

/// 缓存的目录与校验信息；etag 用于下次刷新的 304 增量校验。
class CachedModelCatalog {
  const CachedModelCatalog({required this.catalog, this.etag});

  final ModelCatalog catalog;
  final String? etag;
}

/// 目录文件缓存：运行期刷新结果落盘在应用私有目录 `model_catalog/` 下，
/// 优先于打包进来的内置快照。损坏或缺失一律视为无缓存，不阻塞启动。
class ModelCatalogCache {
  ModelCatalogCache(this.root);

  /// 缓存根目录；测试注入临时目录。
  final Directory root;

  static Future<ModelCatalogCache> create() async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      return ModelCatalogCache(
        Directory(p.join(documents.path, 'model_catalog')),
      );
    } on Object catch (error) {
      throw StorageFailure('打开模型目录缓存失败', cause: error);
    }
  }

  File get _file => File(p.join(root.path, 'catalog.json'));

  Future<CachedModelCatalog?> read() async {
    try {
      if (!await _file.exists()) return null;
      final text = await _file.readAsString();
      final catalog = ModelCatalog.tryParse(text);
      if (catalog == null) return null;
      final decoded = jsonDecode(text);
      final etag = decoded is Map ? decoded['etag'] : null;
      return CachedModelCatalog(
        catalog: catalog,
        etag: etag is String ? etag : null,
      );
    } on Object {
      return null;
    }
  }

  /// 先写临时文件再 rename，避免半截文件被当成有效缓存。
  Future<void> write(CachedModelCatalog value) async {
    Directory? staging;
    try {
      await root.create(recursive: true);
      final payload = <String, dynamic>{
        ...value.catalog.toJson(),
        if (value.etag != null) 'etag': value.etag,
      };
      // 每次写入有独立暂存路径，避免页面重新打开后的并发写互相覆盖临时文件。
      staging = await root.createTemp('.catalog-');
      final temp = File(p.join(staging.path, 'catalog.json'));
      await temp.writeAsString(jsonEncode(payload), flush: true);
      await temp.rename(_file.path);
    } on Object catch (error) {
      throw StorageFailure('保存模型目录缓存失败', cause: error);
    } finally {
      try {
        await staging?.delete(recursive: true);
      } on FileSystemException {
        // 已成功发布的目录不因暂存清理失败而回报保存失败。
      }
    }
  }

  Future<void> clear() async {
    try {
      if (await _file.exists()) await _file.delete();
    } on Object {
      // 删除失败不影响后续读取路径。
    }
  }
}

// 可选缓存失败应立即回退，不能让 Riverpod 自动重试一直占住目录 Future。
Duration? _noCacheRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true, retry: _noCacheRetry)
Future<ModelCatalogCache> modelCatalogCache(Ref ref) {
  return ModelCatalogCache.create();
}

/// 生效目录：内置快照为基线，存在刷新缓存时覆盖。只读盘，无网络副作用；
/// 联网刷新由用户动作触发，完成后 invalidate 本 provider。
@Riverpod(keepAlive: true, dependencies: [modelCatalogCache])
Future<ModelCatalog> modelCatalog(Ref ref) async {
  try {
    // 首次创建运行快照也必须等待本地缓存，不能把异步加载中的缓存当作缺失。
    final cache = await ref.watch(modelCatalogCacheProvider.future);
    final cached = await cache.read();
    if (cached != null) return cached.catalog;
  } on Object {
    // 缓存目录不可用或读取失败仍可使用内置快照。
  }
  try {
    final data = await rootBundle.load('assets/models_catalog.json');
    return ModelCatalog.tryParse(
          utf8.decode(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          ),
        ) ??
        ModelCatalog.empty;
  } on Object {
    // 资产缺失/损坏 → 空目录，全部走本地默认。
    return ModelCatalog.empty;
  }
}
