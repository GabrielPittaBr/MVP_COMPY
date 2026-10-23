import 'package:flutter/foundation.dart';

import '../data/admin_events_repository.dart';

class AdminEventsListState {
  const AdminEventsListState({
    required this.filters,
    this.events = const <AdminEventRecord>[],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.isFromCache = false,
    this.hasMore = false,
    this.cursor,
    this.error,
  });

  final AdminEventsFilters filters;
  final List<AdminEventRecord> events;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isFromCache;
  final bool hasMore;
  final AdminEventCursor? cursor;
  final Object? error;

  AdminEventsListState copyWith({
    List<AdminEventRecord>? events,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isFromCache,
    bool? hasMore,
    AdminEventCursor? cursor,
    bool clearCursor = false,
    Object? error,
    bool clearError = false,
  }) => AdminEventsListState(
    filters: filters,
    events: events ?? this.events,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isFromCache: isFromCache ?? this.isFromCache,
    hasMore: hasMore ?? this.hasMore,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    error: clearError ? null : error ?? this.error,
  );
}

/// Lista paginada de Eventos Esportivos. Leitura única por página: a lista
/// administrativa não precisa acompanhar cada join em tempo real.
class AdminEventsController extends ChangeNotifier {
  AdminEventsController(this._repository)
    : _state = const AdminEventsListState(filters: AdminEventsFilters());

  final AdminEventsRepository _repository;
  AdminEventsListState _state;
  int _generation = 0;
  bool _started = false;
  bool _retryingMore = false;

  AdminEventsListState get state => _state;

  void start() {
    if (_started) return;
    _started = true;
    _loadFirstPage();
  }

  void updateFilters(AdminEventsFilters filters) {
    if (filters == _state.filters) return;
    _state = AdminEventsListState(filters: filters);
    _loadFirstPage();
  }

  Future<void> loadNextPage() async {
    final cursor = _state.cursor;
    if (_state.isLoadingMore || !_state.hasMore || cursor == null) return;
    _retryingMore = true;
    _state = _state.copyWith(isLoadingMore: true, clearError: true);
    notifyListeners();
    await _loadPage(_generation, after: cursor);
  }

  Future<void> retry() => _retryingMore && _state.cursor != null
      ? loadNextPage()
      : _loadFirstPage();

  Future<void> _loadFirstPage() {
    final generation = ++_generation;
    _retryingMore = false;
    _state = AdminEventsListState(filters: _state.filters);
    notifyListeners();
    return _loadPage(generation, after: null);
  }

  Future<void> _loadPage(
    int generation, {
    required AdminEventCursor? after,
  }) async {
    try {
      final page = await _repository.searchEvents(_state.filters, after: after);
      if (generation != _generation) return;
      final unique = <String, AdminEventRecord>{
        if (after != null)
          for (final event in _state.events) event.id: event,
        for (final event in page.events) event.id: event,
      };
      _state = _state.copyWith(
        events: List<AdminEventRecord>.unmodifiable(unique.values),
        isLoading: false,
        isLoadingMore: false,
        isFromCache: after != null
            ? _state.isFromCache || page.isFromCache
            : page.isFromCache,
        hasMore: page.cursor != null,
        cursor: page.cursor,
        clearCursor: page.cursor == null,
        clearError: true,
      );
      _retryingMore = false;
      notifyListeners();
    } on Object catch (error) {
      if (generation != _generation) return;
      _state = _state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: error,
      );
      notifyListeners();
    }
  }
}
