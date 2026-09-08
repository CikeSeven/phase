import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/assistants/assistants_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/providers_config/provider_edit_page.dart';
import '../../features/providers_config/providers_page.dart';
import '../../features/settings/settings_page.dart';

part 'app_router.g.dart';

/// 应用路由表。页面转场统一由主题（DESIGN.md §6）提供。
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const ChatPage()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'providers',
            builder: (context, state) => const ProvidersPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const ProviderEditPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    ProviderEditPage(profileId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/assistants',
        builder: (context, state) => const AssistantsPage(),
      ),
    ],
  );
}
