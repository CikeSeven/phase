import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../tools/tool.dart';
import 'process_api.g.dart';
import 'process_driver.dart';
import 'rootfs_archive.dart';

class LinuxImage {
  const LinuxImage({
    required this.revision,
    required this.url,
    required this.digest,
    required this.downloadBytes,
  });
  final String revision;
  final String url;
  final String digest;
  final int downloadBytes;
}

abstract final class UbuntuImage {
  static const revision = '24.04.5-arm64';
  static const url =
      'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-arm64.tar.gz';
  static const sha256Digest =
      'a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2';
  static const downloadBytes = 29936675;
  static const fileBytes = 104728695;
  static const codename = 'noble';
  static const traceUrl = 'https://www.cloudflare.com/cdn-cgi/trace';
  static const upstreamAptMirror = 'http://ports.ubuntu.com/ubuntu-ports';
  static const chinaAptMirror =
      'http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports';
  static const manifest = LinuxImage(
    revision: revision,
    url: url,
    digest: sha256Digest,
    downloadBytes: downloadBytes,
  );
  // Archive + bounded uncompressed tar + extracted files + filesystem overhead.
  static const requiredFreeBytes =
      downloadBytes + RootfsArchive.maxTarBytes * 2 + 64 * 1024 * 1024;
}

class LinuxInstaller {
  LinuxInstaller(
    this.repository,
    this.driver,
    this.dio, {
    this.image = UbuntuImage.manifest,
    this.traceUrl = UbuntuImage.traceUrl,
  });
  final LinuxImage image;
  final WorkspaceRepository repository;
  final ProcessDriver driver;
  final Dio dio;
  final String traceUrl;

  Future<void> install(
    RunCancellation cancellation,
    void Function(EnvironmentPhase, int, int?) progress,
  ) async {
    repository.beginEnvironmentChange();
    final owner = 'install-${generateId()}';
    final staging = Directory(
      p.join(repository.root.path, 'staging', generateId()),
    );
    final rootfs = Directory(p.join(staging.path, 'rootfs'));
    RuntimeEnvironment? old;
    Directory? installed;
    var committed = false;
    final stops = driver.stops.listen((id) {
      if (id == owner) cancellation.cancel();
    });
    final token = CancelToken();
    cancellation.whenCancelled.then((_) {
      if (!token.isCancelled) token.cancel();
    });
    Future<void> stage(EnvironmentPhase phase) async {
      cancellation.throwIfCancelled();
      await repository.saveEnvironment(
        RuntimeEnvironment(
          phase: phase,
          rootPath: old?.rootPath,
          imageUrl: old?.imageUrl,
          imageDigest: old?.imageDigest,
          downloadBytes: old?.downloadBytes ?? 0,
          revision: old?.revision,
          installedBytes: old?.installedBytes ?? 0,
          installedDependencies: old?.installedDependencies ?? const {},
        ),
      );
      progress(
        phase,
        0,
        phase == EnvironmentPhase.downloading ? image.downloadBytes : null,
      );
    }

    try {
      old = await repository.environment();
      final info = await driver.info();
      if (!info.available) {
        throw const WorkspaceFailure(
          'unsupportedAbi',
          'Linux 环境目前仅支持 ARM64 设备',
        );
      }
      if (info.freeBytes < UbuntuImage.requiredFreeBytes) {
        throw const WorkspaceFailure('noSpace', '安装环境至少需要 605 MiB 可用空间，请清理后重试');
      }
      await driver.beginTask(owner, '环境安装');
      await staging.create(recursive: true);
      final archive = File(p.join(staging.path, 'ubuntu.tar.gz'));
      await stage(EnvironmentPhase.downloading);
      final response = await dio.get<ResponseBody>(
        image.url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
        ),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const WorkspaceFailure('downloadFailed', 'Ubuntu 镜像下载失败');
      }
      final output = await archive.open(mode: FileMode.write);
      var received = 0;
      try {
        await for (final bytes in response.data!.stream) {
          cancellation.throwIfCancelled();
          received += bytes.length;
          if (received > image.downloadBytes) {
            throw const WorkspaceFailure('downloadSize', '镜像大小与固定清单不一致');
          }
          await output.writeFrom(bytes);
          progress(EnvironmentPhase.downloading, received, image.downloadBytes);
        }
      } finally {
        await output.close();
      }
      if (received != image.downloadBytes) {
        throw const WorkspaceFailure('downloadSize', '镜像下载不完整');
      }
      await stage(EnvironmentPhase.verifying);
      final digest = await sha256.bind(archive.openRead()).first;
      if (digest.toString() != image.digest) {
        throw const WorkspaceFailure('digestMismatch', 'Ubuntu 镜像校验失败，请重新下载');
      }
      await stage(EnvironmentPhase.extracting);
      final installedBytes = await RootfsArchive().extract(
        archive,
        rootfs,
        cancellation,
        setModes: driver.setModes,
        progress: (bytes) => progress(EnvironmentPhase.extracting, bytes, null),
      );
      await stage(EnvironmentPhase.configuring);
      for (final path in ['tmp', 'root', 'workspace', 'proc', 'dev']) {
        await Directory(p.join(rootfs.path, path)).create(recursive: true);
      }
      // Android's resolver configuration is not a bindable resolv.conf.
      final resolv = File(p.join(rootfs.path, 'etc', 'resolv.conf'));
      if (await FileSystemEntity.type(resolv.path, followLinks: false) ==
          FileSystemEntityType.link) {
        await Link(resolv.path).delete();
      }
      await resolv.writeAsString('nameserver 1.1.1.1\nnameserver 8.8.8.8\n');
      // One best-effort probe picks the apt mirror for this install; failures
      // keep the upstream default. Plain HTTP avoids needing a guest CA bundle.
      final aptMirror = await _aptMirror(token);
      cancellation.throwIfCancelled();
      final legacySources = File(
        p.join(rootfs.path, 'etc', 'apt', 'sources.list'),
      );
      if (await legacySources.exists()) await legacySources.delete();
      final ubuntuSources = File(
        p.join(rootfs.path, 'etc', 'apt', 'sources.list.d', 'ubuntu.sources'),
      );
      await ubuntuSources.parent.create(recursive: true);
      final codename = UbuntuImage.codename;
      await ubuntuSources.writeAsString(
        'Types: deb\n'
        'URIs: $aptMirror\n'
        'Suites: $codename $codename-updates $codename-backports '
        '$codename-security\n'
        'Components: main restricted universe multiverse\n'
        'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n',
      );
      await stage(EnvironmentPhase.checking);
      final probe = Directory(p.join(staging.path, 'probe'));
      await probe.create();
      cancellation.throwIfCancelled();
      final process = await driver.start(
        LinuxProcessSpec(
          ownerId: owner,
          processId: generateId(),
          rootfs: rootfs.path,
          workspace: probe.path,
          executable: '/bin/sh',
          argv: [
            '-c',
            'printf phase-linux-ready > /workspace/check; printf stdout; printf stderr >&2; exit 23',
          ],
          cwd: '/workspace',
          environment: {},
          timeoutMs: 60000,
          outputLimitBytes: 65536,
        ),
        (_, _) async {},
      );
      await process.closeInput();
      final result = await waitForProcess(process, cancellation);
      cancellation.throwIfCancelled();
      if (result.exitCode != 23 ||
          result.error != null ||
          result.timedOut ||
          !await File(p.join(probe.path, 'check')).exists() ||
          await File(p.join(probe.path, 'check')).readAsString() !=
              'phase-linux-ready') {
        throw const WorkspaceFailure(
          'environmentCheck',
          'Ubuntu shell 或文件读写检查失败，环境尚不可用',
        );
      }
      installed = Directory(
        p.join(
          repository.root.path,
          'environments',
          '${image.revision}-${generateId()}',
        ),
      );
      await installed.parent.create(recursive: true);
      await rootfs.rename(installed.path);
      cancellation.throwIfCancelled();
      await repository.saveEnvironment(
        RuntimeEnvironment(
          phase: EnvironmentPhase.ready,
          imageUrl: image.url,
          imageDigest: image.digest,
          downloadBytes: image.downloadBytes,
          rootPath: installed.path,
          revision: image.revision,
          installedBytes: installedBytes,
        ),
      );
      committed = true;
      progress(EnvironmentPhase.ready, installedBytes, installedBytes);
      if (old.rootPath != null && old.rootPath != installed.path) {
        await Directory(old.rootPath!).delete(recursive: true);
      }
    } catch (error) {
      if (old != null && !committed) {
        final message = cancellation.isCancelled
            ? '安装已取消，已有工作区保留'
            : error is Failure
            ? error.userMessage
            : '环境安装失败，请检查网络和可用空间后重试';
        await repository.saveEnvironment(
          RuntimeEnvironment(
            phase: old.ready
                ? EnvironmentPhase.ready
                : cancellation.isCancelled
                ? EnvironmentPhase.cancelled
                : EnvironmentPhase.failed,
            rootPath: old.rootPath,
            imageUrl: old.imageUrl,
            imageDigest: old.imageDigest,
            downloadBytes: old.downloadBytes,
            revision: old.revision,
            installedBytes: old.installedBytes,
            installedDependencies: old.installedDependencies,
            error: message,
          ),
        );
      }
      if (cancellation.isCancelled) throw const ToolCancelled();
      if (error is Failure) rethrow;
      throw const WorkspaceFailure(
        'installationFailed',
        'Ubuntu 环境安装失败，请检查网络和可用空间后重试',
      );
    } finally {
      try {
        await driver.endTask(owner);
        if (!committed && installed != null && await installed.exists()) {
          await installed.delete(recursive: true);
        }
        if (await staging.exists()) await staging.delete(recursive: true);
      } finally {
        await stops.cancel();
        repository.endEnvironmentChange();
      }
    }
  }

  Future<String> _aptMirror(CancelToken token) async {
    try {
      final response = await dio.get<String>(
        traceUrl,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final location = RegExp(
        r'^loc=(\S+)',
        multiLine: true,
      ).firstMatch(response.data ?? '')?.group(1);
      if (location == 'CN') return UbuntuImage.chinaAptMirror;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      // Probing is best-effort; keep the upstream default on failure.
    }
    return UbuntuImage.upstreamAptMirror;
  }

  Future<void> uninstall() async {
    repository.beginEnvironmentChange();
    try {
      final old = await repository.environment();
      // Revoke new runs before deleting; a failure retains the path for retry.
      await repository.saveEnvironment(
        RuntimeEnvironment(
          phase: EnvironmentPhase.failed,
          rootPath: old.rootPath,
          imageUrl: old.imageUrl,
          imageDigest: old.imageDigest,
          downloadBytes: old.downloadBytes,
          revision: old.revision,
          installedBytes: old.installedBytes,
          installedDependencies: old.installedDependencies,
          error: '环境卸载未完成，可重试',
        ),
      );
      if (old.rootPath != null && await Directory(old.rootPath!).exists()) {
        await Directory(old.rootPath!).delete(recursive: true);
      }
      await repository.saveEnvironment(const RuntimeEnvironment());
    } on FileSystemException {
      throw const WorkspaceFailure('uninstallFailed', '环境文件删除失败，请重试；工作区文件保留');
    } finally {
      repository.endEnvironmentChange();
    }
  }
}
