import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/admin_places_repository.dart';

class AdminPlacesListState {
  const AdminPlacesListState({
    required this.filters,
    this.places = const <AdminPlaceSummary>[],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.isFromCache = false,
    this.hasMore = false,
    this.error,
  });

  final AdminPlacesFilters filters;
  final List<AdminPlaceSummary> places;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isFromCache;
  final bool hasMore;
  final Object? error;

  AdminPlacesListState copyWith({
    AdminPlacesFilters? filters,
    List<AdminPlaceSummary>? places,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isFromCache,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) => AdminPlacesListState(
    filters: filters ?? this.filters,
    places: places ?? this.places,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isFromCache: isFromCache ?? this.isFromCache,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : error ?? this.error,
  );
}

class AdminPlacesController extends ChangeNotifier {
  AdminPlacesController(
    this._repository, {
    AdminPlaceStatusFilter initialStatus = AdminPlaceStatusFilter.all,
  }) : _state = AdminPlacesListState(
         filters: AdminPlacesFilters(status: initialStatus),
       );

  static const int pageSize = FirebaseAdminPlacesRepository.pageSize;
  final AdminPlacesRepository _repository;
  AdminPlacesListState _state;
  final List<StreamSubscription<AdminPlacesPageSnapshot>?> _subscriptions =
      <StreamSubscription<AdminPlacesPageSnapshot>?>[];
  final List<AdminPlacesPageSnapshot?> _pages = <AdminPlacesPageSnapshot?>[];
  int _generation = 0;
  bool _started = false;

  AdminPlacesListState get state => _state;

  void start() {
    if (_started) return;
    _started = true;
    _watchFirstPage();
  }

  void updateFilters(AdminPlacesFilters filters) {
    if (filters == _state.filters) return;
    _state = AdminPlacesListState(filters: filters);
    notifyListeners();
    _watchFirstPage();
  }

  void retry() => _watchFirstPage();

  void loadNextPage() {
    if (_state.isLoadingMore || !_state.hasMore || _pages.isEmpty) return;
    final cursor = _pages.last?.cursor;
    if (cursor == null) return;
    final index = _pages.length;
    _state = _state.copyWith(isLoadingMore: true, clearError: true);
    notifyListeners();
    _watchPage(index, cursor, _generation);
  }

  void _watchFirstPage() {
    _generation += 1;
    final generation = _generation;
    _cancelPages();
    _pages.clear();
    _subscriptions.clear();
    _state = _state.copyWith(
      places: const <AdminPlaceSummary>[],
      isLoading: true,
      isLoadingMore: false,
      isFromCache: false,
      hasMore: false,
      clearError: true,
    );
    notifyListeners();
    _watchPage(0, null, generation);
  }

  void _watchPage(int index, AdminPlaceCursor? cursor, int generation) {
    while (_subscriptions.length <= index) {
      _subscriptions.add(null);
      _pages.add(null);
    }
    _subscriptions[index] = _repository
        .watchPage(_state.filters, after: cursor)
        .listen(
          (page) {
            if (generation != _generation) return;
            final previous = _pages[index];
            if (previous != null &&
                !_sameQueryPosition(previous.places, page.places)) {
              // Mudança de ordenação ou membership invalida cursores posteriores.
              // Reinicia a partir da primeira página para não ocultar/duplicar itens.
              _watchFirstPage();
              return;
            }
            _pages[index] = page;
            _publishPages();
          },
          onError: (Object error) {
            if (generation != _generation) return;
            _state = _state.copyWith(
              isLoading: false,
              isLoadingMore: false,
              error: error,
            );
            notifyListeners();
          },
        );
  }

  void _publishPages() {
    final pages = _pages.whereType<AdminPlacesPageSnapshot>().toList();
    final byId = <String, AdminPlaceSummary>{};
    for (final page in pages) {
      for (final place in page.places) {
        byId[place.id] = place;
      }
    }
    _state = _state.copyWith(
      places: List<AdminPlaceSummary>.unmodifiable(byId.values),
      isLoading: false,
      isLoadingMore: false,
      isFromCache: pages.any((page) => page.isFromCache),
      hasMore: pages.isNotEmpty && pages.last.cursor != null,
      clearError: true,
    );
    notifyListeners();
  }

  bool _sameQueryPosition(
    List<AdminPlaceSummary> left,
    List<AdminPlaceSummary> right,
  ) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id ||
          left[i].nameLower != right[i].nameLower) {
        return false;
      }
    }
    return true;
  }

  void _cancelPages() {
    for (final subscription in _subscriptions) {
      unawaited(subscription?.cancel());
    }
  }

  @override
  void dispose() {
    _cancelPages();
    super.dispose();
  }
}
