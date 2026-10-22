import 'package:flutter/foundation.dart';

import '../data/admin_users_repository.dart';

class AdminUsersListState {
  const AdminUsersListState({
    required this.searchType,
    required this.query,
    this.items = const <AdminUserListItem>[],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.isFromCache = false,
    this.hasMore = false,
    this.cursor,
    this.exactNotFound = false,
    this.error,
  });

  final AdminUserSearchType searchType;
  final String query;
  final List<AdminUserListItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isFromCache;
  final bool hasMore;
  final AdminUserCursor? cursor;
  final bool exactNotFound;
  final Object? error;

  AdminUsersListState copyWith({
    AdminUserSearchType? searchType,
    String? query,
    List<AdminUserListItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isFromCache,
    bool? hasMore,
    AdminUserCursor? cursor,
    bool clearCursor = false,
    bool? exactNotFound,
    Object? error,
    bool clearError = false,
  }) => AdminUsersListState(
    searchType: searchType ?? this.searchType,
    query: query ?? this.query,
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isFromCache: isFromCache ?? this.isFromCache,
    hasMore: hasMore ?? this.hasMore,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    exactNotFound: exactNotFound ?? this.exactNotFound,
    error: clearError ? null : error ?? this.error,
  );
}

class AdminUsersController extends ChangeNotifier {
  AdminUsersController(this._repository)
    : _state = const AdminUsersListState(
        searchType: AdminUserSearchType.name,
        query: '',
      );

  final AdminUsersRepository _repository;
  AdminUsersListState _state;
  int _generation = 0;
  bool _started = false;
  bool _retryingMore = false;

  AdminUsersListState get state => _state;

  void start() {
    if (_started) return;
    _started = true;
    search(AdminUserSearchType.name, '');
  }

  Future<AdminUserDetailsResult?> search(
    AdminUserSearchType type,
    String query,
  ) async {
    final generation = ++_generation;
    _retryingMore = false;
    _state = AdminUsersListState(
      searchType: type,
      query: query,
      isLoading: true,
    );
    notifyListeners();

    if (type == AdminUserSearchType.uid || type == AdminUserSearchType.email) {
      if (query.trim().isEmpty) {
        _state = _state.copyWith(isLoading: false, exactNotFound: true);
        notifyListeners();
        return null;
      }
      try {
        final result = await _repository.findExact(type, query);
        if (generation != _generation) return null;
        _state = _state.copyWith(
          isLoading: false,
          exactNotFound: result == null,
          clearError: true,
        );
        notifyListeners();
        return result;
      } on Object catch (error) {
        if (generation == _generation) {
          _state = _state.copyWith(isLoading: false, error: error);
          notifyListeners();
        }
        return null;
      }
    }

    await _loadProfilePage(generation, after: null, append: false);
    return null;
  }

  Future<void> loadNextPage() async {
    final cursor = _state.cursor;
    if (_state.isLoadingMore || !_state.hasMore || cursor == null) return;
    _retryingMore = true;
    final generation = _generation;
    _state = _state.copyWith(isLoadingMore: true, clearError: true);
    notifyListeners();
    await _loadProfilePage(generation, after: cursor, append: true);
  }

  Future<void> retry() async {
    if (_retryingMore && _state.cursor != null) {
      await loadNextPage();
    } else {
      await search(_state.searchType, _state.query);
    }
  }

  Future<void> _loadProfilePage(
    int generation, {
    required AdminUserCursor? after,
    required bool append,
  }) async {
    try {
      final page = await _repository.searchProfiles(
        _state.searchType,
        _state.query,
        after: after,
      );
      if (generation != _generation) return;
      final combined = append
          ? <AdminUserListItem>[..._state.items, ...page.items]
          : page.items;
      final unique = <String, AdminUserListItem>{};
      for (final item in combined) {
        unique[item.profile.uid] = item;
      }
      _state = _state.copyWith(
        items: List<AdminUserListItem>.unmodifiable(unique.values),
        isLoading: false,
        isLoadingMore: false,
        isFromCache: append
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
