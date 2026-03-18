/// Domain model for menu category (matches Categories table).
/// Used for breadcrumb navigation and category grid until Drift code gen is run.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.parentId,
    this.color,
    this.imageUrl,
  });

  final int id;
  final String name;
  final int? parentId;
  final String? color;
  final String? imageUrl;
}
