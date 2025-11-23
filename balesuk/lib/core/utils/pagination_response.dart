// ----------------- pagination_models.dart -----------------

/// Represents the metadata required for client-side pagination.
class PaginationMetadata {
  final int totalCount;    // Total number of items in the entire collection
  final int currentPage;   // The current page number (1-based)
  final int pageSize;      // The number of items per page (limit)
  final int offset;        // The starting index of the current list (skip)
  final int totalPages;    // Calculated total pages

  PaginationMetadata({
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
    required this.offset,
  }) : totalPages = (totalCount / pageSize).ceil();
}

/// A generic structure to hold a paginated list of items (T)
/// This becomes the payload (T) inside Result<T>.
class PaginatedResponse<T> {
  final List<T> data;
  final PaginationMetadata metadata;

  PaginatedResponse({
    required this.data,
    required this.metadata,
  });
}