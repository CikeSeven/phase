import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/repositories/project_repository.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_page.dart';
import 'project_navigation.dart';

class ProjectChatPage extends ConsumerStatefulWidget {
  const ProjectChatPage({
    required this.projectId,
    this.conversationId,
    this.navigation,
    super.key,
  });

  final String projectId;
  final String? conversationId;
  final ProjectChatNavigation? navigation;

  @override
  ConsumerState<ProjectChatPage> createState() => _ProjectChatPageState();
}

class _ProjectChatPageState extends ConsumerState<ProjectChatPage> {
  bool _loading = true;
  String? _error;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(activeConversationProvider, (_, next) {
      if (next.projectId == widget.projectId &&
          next.conversationId != widget.conversationId) {
        Future.microtask(_synchronizeRoute);
      }
    });
    Future.microtask(_open);
  }

  @override
  void didUpdateWidget(ProjectChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.conversationId != widget.conversationId) {
      final active = ref.read(activeConversationProvider);
      if (active.projectId == widget.projectId &&
          active.conversationId == widget.conversationId &&
          !_loading &&
          _error == null) {
        return;
      }
      _revision++;
      _loading = true;
      _error = null;
      Future.microtask(_open);
    }
  }

  void _synchronizeRoute() {
    if (!mounted ||
        _loading ||
        _error != null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final active = ref.read(activeConversationProvider);
    if (active.projectId != widget.projectId ||
        active.conversationId == widget.conversationId) {
      return;
    }
    context.replace(
      '/projects/${widget.projectId}/conversations/${active.conversationId ?? 'new'}',
      extra: widget.navigation,
    );
  }

  Future<void> _open() async {
    if (!mounted) return;
    final revision = ++_revision;
    final projectId = widget.projectId;
    final id = widget.conversationId;
    try {
      final repository = await ref.read(projectRepositoryProvider.future);
      final project = await repository.get(projectId);
      if (!mounted ||
          revision != _revision ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (project == null) throw const OperationFailure('项目已不存在');
      final controller = ref.read(chatControllerProvider.notifier);
      if (id == null) {
        controller.startNewConversation(projectId: project.id);
      } else {
        await controller.openConversation(
          id,
          expectedProjectId: project.id,
          isCurrent: () =>
              mounted &&
              revision == _revision &&
              ModalRoute.of(context)?.isCurrent == true,
        );
      }
      if (mounted && revision == _revision) setState(() => _loading = false);
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _loading = false;
        _error = error is Failure ? error.userMessage : '打开项目会话失败，请重试';
      });
    }
  }

  @override
  void dispose() {
    _revision++;
    widget.navigation?.finish();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null) {
      return ChatPage(projectId: widget.projectId);
    }
    return AppScaffold(
      title: '项目会话',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : AppEmptyState(
              icon: LucideIcons.messageSquare,
              title: '无法打开会话',
              message: _error!,
              action: TextButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _open();
                },
                child: const Text('重试'),
              ),
            ),
    );
  }
}
