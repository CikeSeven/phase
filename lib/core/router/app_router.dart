import '../../features/memory/memories_page.dart';
import '../../features/chat/context/conversation_context_page.dart';
import '../../features/workspace/workspaces_page.dart';
import '../../features/workspace/workspace_files_page.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/assistants/assistant_edit_page.dart';
import '../../features/assistants/assistants_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/providers_config/provider_edit_page.dart';
import '../../features/providers_config/providers_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/tools/run_recovery_page.dart';
import '../../features/tools/tool_records_page.dart';
import '../../features/execution/execution_settings_page.dart';
import '../../features/mcp/mcp_servers_page.dart';
import '../../features/mcp/mcp_edit_page.dart';
import '../../features/settings/extensions_page.dart';
import '../../features/skills/skills_page.dart';
import '../../features/skills/skill_import_page.dart';
import '../../features/skills/skill_detail_page.dart';
import '../../features/skills/skill_resource_page.dart';

part 'app_router.g.dart';

/// 应用路由表。页面转场统一由主题（DESIGN.md §6）提供。
///
/// 每条路由必须显式给出 pageBuilder：go_router 18 靠检测 material_ui 包的
/// MaterialApp 决定页面类型，而本应用用的是 Flutter SDK 内置的 MaterialApp，
/// 检测失败会让所有路由退化为无动画的 NoTransitionPage（且失去预测性返回）。
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  MaterialPage<void> materialPage(GoRouterState state, Widget child) {
    return MaterialPage(key: state.pageKey, child: child);
  }

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/conversations/:id/context',
        pageBuilder: (context, state) => materialPage(
          state,
          ConversationContextPage(conversationId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/tasks',
        pageBuilder: (context, state) =>
            materialPage(state, const RunRecoveryPage()),
      ),
      GoRoute(
        path: '/conversations/:id/tools',
        pageBuilder: (context, state) => materialPage(
          state,
          ToolRecordsPage(conversationId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => materialPage(state, const ChatPage()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            materialPage(state, const SettingsPage()),
        routes: [
          GoRoute(
            path: 'memories',
            pageBuilder: (context, state) =>
                materialPage(state, const MemoriesPage()),
          ),
          GoRoute(
            path: 'extensions',
            pageBuilder: (context, state) =>
                materialPage(state, const ExtensionsPage()),
            routes: [
              GoRoute(
                path: 'skills',
                pageBuilder: (context, state) =>
                    materialPage(state, const SkillsPage()),
                routes: [
                  GoRoute(
                    path: 'import',
                    pageBuilder: (context, state) =>
                        materialPage(state, const SkillImportPage()),
                  ),
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => materialPage(
                      state,
                      SkillDetailPage(id: state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'update',
                        pageBuilder: (context, state) => materialPage(
                          state,
                          SkillImportPage(
                            replaceId: state.pathParameters['id']!,
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'resource',
                        pageBuilder: (context, state) => materialPage(
                          state,
                          SkillResourcePage(
                            id: state.pathParameters['id']!,
                            path:
                                state.uri.queryParameters['path'] ?? 'SKILL.md',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'mcp',
                pageBuilder: (context, state) =>
                    materialPage(state, const McpServersPage()),
                routes: [
                  GoRoute(
                    path: 'new',
                    pageBuilder: (context, state) =>
                        materialPage(state, const McpEditPage()),
                  ),
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => materialPage(
                      state,
                      McpEditPage(serverId: state.pathParameters['id']),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'workspaces',
            pageBuilder: (context, state) =>
                materialPage(state, const WorkspacesPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => materialPage(
                  state,
                  WorkspaceFilesPage(
                    id: state.pathParameters['id']!,
                    path: state.uri.queryParameters['path'] ?? '.',
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'execution',
            pageBuilder: (context, state) =>
                materialPage(state, const ExecutionSettingsPage()),
          ),
          GoRoute(
            path: 'providers',
            pageBuilder: (context, state) =>
                materialPage(state, const ProvidersPage()),
            routes: [
              GoRoute(
                path: 'new',
                pageBuilder: (context, state) =>
                    materialPage(state, const ProviderEditPage()),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => materialPage(
                  state,
                  ProviderEditPage(profileId: state.pathParameters['id']),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/assistants',
        pageBuilder: (context, state) =>
            materialPage(state, const AssistantsPage()),
        routes: [
          GoRoute(
            path: 'new',
            pageBuilder: (context, state) =>
                materialPage(state, const AssistantEditPage()),
          ),
          GoRoute(
            path: ':id',
            pageBuilder: (context, state) => materialPage(
              state,
              AssistantEditPage(assistantId: state.pathParameters['id']),
            ),
          ),
        ],
      ),
    ],
  );
}
