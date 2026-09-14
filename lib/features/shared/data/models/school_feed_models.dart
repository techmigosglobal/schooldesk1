import 'package:schooldesk1/features/shared/data/models/backend_models.dart';

/// Result of a feed read where a dashboard can still render its other data
/// when the feed transport fails. A missing page is an error, never an empty
/// successful dataset.
class SchoolFeedLoadResult {
  final PaginatedList<Map<String, dynamic>>? page;
  final Object? error;

  const SchoolFeedLoadResult({this.page, this.error});

  bool get hasData => page != null;
  bool get isStale => page?.isStale ?? false;
}
