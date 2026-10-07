import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/attachment.dart';
import '../../data/models/conversation.dart';
import '../../data/models/project.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/project_repository.dart';

part 'project_providers.g.dart';

@riverpod
Stream<List<Project>> projects(Ref ref) async* {
  yield* (await ref.watch(projectRepositoryProvider.future)).watchProjects();
}

@riverpod
Stream<Project?> project(Ref ref, String id) async* {
  yield* (await ref.watch(projectRepositoryProvider.future)).watchProject(id);
}

@riverpod
Stream<List<Conversation>> projectConversations(Ref ref, String id) async* {
  yield* (await ref.watch(conversationRepositoryProvider.future))
      .watchProjectConversations(id);
}

@riverpod
Stream<List<Attachment>> projectAttachments(Ref ref, String id) async* {
  yield* (await ref.watch(projectRepositoryProvider.future))
      .watchAttachments(id);
}
