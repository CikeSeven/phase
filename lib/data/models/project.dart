class Project {
  const Project({
    required this.id,
    required this.name,
    required this.workspaceId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String workspaceId;
  final DateTime createdAt;
}
