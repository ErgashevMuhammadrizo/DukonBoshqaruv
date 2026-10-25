import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

const _configuredApiBaseUrl =
    String.fromEnvironment('API_BASE_URL');

String get _apiBaseUrl {
  final configured = _configuredApiBaseUrl.trim();
  final value = configured.isNotEmpty
      ? configured
      : 'https://dukonboshqaruvi-production.up.railway.app/api/v1/';

  return value.endsWith('/') ? value : '$value/';
}

class Api {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: _apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  final FlutterSecureStorage secure =
      const FlutterSecureStorage();

  void Function()? onLogout;

  String? _sessionKey;
  String? get sessionKey => _sessionKey;

  bool _refreshRejected = false;
  Object? _lastRefreshError;
  Future<bool>? _refreshFuture;

  static const _profileKey = 'offline_profile_v2';
  static const _checkedKey = 'offline_checked_v2';
  static const _expiryKey = 'offline_expiry_v2';
  static const _serverKey = 'offline_server_v2';

  static const _exemptPaths = {
    'auth/login/',
    'auth/activate/',
    'auth/set-password/',
    'auth/token/refresh/',
    'auth/password-reset/confirm/',
  };

  Api() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final path =
                options.path.replaceAll(RegExp(r'^/+'), '');

            if (_exemptPaths.contains(path)) {
              options.headers.remove('Authorization');
            } else {
              final token = await secure.read(key: 'access');

              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }

            handler.next(options);
          } catch (error) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
              ),
            );
          }
        },
        onError: (error, handler) async {
          final path =
              error.requestOptions.path.replaceAll(RegExp(r'^/+'), '');

          final alreadyRetried =
              error.requestOptions.extra['auth_retried'] == true;

          if (error.response?.statusCode != 401 ||
              _exemptPaths.contains(path) ||
              alreadyRetried) {
            handler.next(error);
            return;
          }

          final refreshed = await _refreshTokens();

          if (!refreshed) {
            if (_refreshRejected) {
              await _clearSession();
              onLogout?.call();
            }

            // Refresh vaqtida internet uzilgan bo‘lsa,
            // asl 401 ni tarmoq xatosidan farqlaymiz.
            final refreshError = _lastRefreshError;

            if (isNetworkError(refreshError)) {
              handler.next(
                DioException(
                  requestOptions: error.requestOptions,
                  type: refreshError is DioException
                      ? refreshError.type
                      : DioExceptionType.connectionTimeout,
                  error: refreshError,
                  message: 'Sessiyani yangilashda tarmoq uzildi.',
                ),
              );
            } else {
              handler.next(error);
            }

            return;
          }

          try {
            final token = await secure.read(key: 'access');
            final request = error.requestOptions;

            request.extra['auth_retried'] = true;

            if (token != null) {
              request.headers['Authorization'] = 'Bearer $token';
            }

            final response = await dio.fetch<dynamic>(request);
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.next(retryError);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
  }

  static bool isNetworkError(Object? error) {
    if (error is TimeoutException) return true;

    return error is DioException &&
        {
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
        }.contains(error.type);
  }

  void _setIdentity(Map<String, dynamic> profile) {
    final id = profile['id'];

    if (id == null) {
      throw const FormatException(
        'Profil javobida foydalanuvchi ID mavjud emas.',
      );
    }

    _sessionKey = base64Url
        .encode(utf8.encode('${dio.options.baseUrl}|$id'))
        .replaceAll('=', '');
  }

  Future<void> _clearOfflineProfile() async {
    await secure.delete(key: _profileKey);
    await secure.delete(key: _checkedKey);
    await secure.delete(key: _expiryKey);
    await secure.delete(key: _serverKey);
  }

  Future<void> _clearSession() async {
    _sessionKey = null;

    await secure.delete(key: 'access');
    await secure.delete(key: 'refresh');
    await _clearOfflineProfile();
  }

  Future<bool> _refreshTokens() {
    final running = _refreshFuture;
    if (running != null) return running;

    final future = _performRefresh();
    _refreshFuture = future;

    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
  }

  Future<bool> _performRefresh() async {
    _refreshRejected = false;
    _lastRefreshError = null;

    try {
      final refresh = await secure.read(key: 'refresh');

      if (refresh == null || refresh.trim().isEmpty) {
        _refreshRejected = true;
        return false;
      }

      final response = await dio.post(
        'auth/token/refresh/',
        data: {'refresh': refresh},
      );

      final data =
          Map<String, dynamic>.from(response.data as Map);

      final access = data['access'];

      if (access is! String || access.isEmpty) {
        throw const FormatException(
          'Server access token qaytarmadi.',
        );
      }

      await secure.write(key: 'access', value: access);

      final nextRefresh = data['refresh'];

      if (nextRefresh is String && nextRefresh.isNotEmpty) {
        await secure.write(
          key: 'refresh',
          value: nextRefresh,
        );
      }

      return true;
    } catch (error) {
      _lastRefreshError = error;

      if (error is DioException) {
        _refreshRejected =
            error.response?.statusCode == 401 ||
            error.response?.statusCode == 403;
      }

      return false;
    }
  }

  Future<Map<String, dynamic>?> offlineProfile() async {
    try {
      final refresh = await secure.read(key: 'refresh');
      final raw = await secure.read(key: _profileKey);
      final server = await secure.read(key: _serverKey);

      final checkedAt = DateTime.tryParse(
        await secure.read(key: _checkedKey) ?? '',
      );

      final expiresAt = DateTime.tryParse(
        await secure.read(key: _expiryKey) ?? '',
      );

      if (refresh == null ||
          refresh.isEmpty ||
          raw == null ||
          server != dio.options.baseUrl ||
          checkedAt == null ||
          expiresAt == null) {
        return null;
      }

      final now = DateTime.now().toUtc();

      if (now.isBefore(checkedAt.toUtc()) ||
          now.difference(checkedAt.toUtc()) >=
              const Duration(hours: 24) ||
          !expiresAt.toUtc().isAfter(now)) {
        return null;
      }

      final profile =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);

      if (profile['is_superadmin'] == true ||
          profile['superadmin'] == true ||
          profile['is_active'] == false ||
          profile['needs_password_change'] == true ||
          profile['force_password_change'] == true) {
        return null;
      }

      _setIdentity(profile);
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<bool> login(
    String username,
    String password,
  ) async {
    await _clearSession();

    final response = await dio.post(
      'auth/login/',
      data: {
        'username': username.trim(),
        'password': password,
      },
    );

    final data =
        Map<String, dynamic>.from(response.data as Map);

    await secure.write(
      key: 'access',
      value: data['access'] as String,
    );

    await secure.write(
      key: 'refresh',
      value: data['refresh'] as String,
    );

    return true;
  }

  Future<bool> restore() async {
    final refresh = await secure.read(key: 'refresh');

    if (refresh == null || refresh.isEmpty) return false;

    final restored = await _refreshTokens();

    if (!restored) {
      if (_refreshRejected) {
        await _clearSession();
        return false;
      }

      if (isNetworkError(_lastRefreshError)) {
        return await offlineProfile() != null;
      }

      return false;
    }

    try {
      await me();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final refresh = await secure.read(key: 'refresh');

      if (refresh != null) {
        await dio.post(
          'auth/logout/',
          data: {'refresh': refresh},
        );
      }
    } catch (_) {
      // Serverga chiqish xabari yetib bormasa ham,
      // qurilmadagi sessiya tozalanadi.
    } finally {
      await _clearSession();
    }
  }

  Future<Map<String, dynamic>> me() async {
    Map<String, dynamic> profile;

    try {
      final response = await dio.get('me/');
      profile =
          Map<String, dynamic>.from(response.data as Map);
    } catch (error) {
      if (isNetworkError(error)) {
        final cached = await offlineProfile();
        if (cached != null) return cached;
      }

      if (error is DioException &&
          {
            401,
            403,
          }.contains(error.response?.statusCode)) {
        await _clearOfflineProfile();
      }

      rethrow;
    }

    _setIdentity(profile);

    final isAdmin = profile['is_superadmin'] == true ||
        profile['superadmin'] == true;

    final blocked = profile['is_active'] == false ||
        profile['needs_password_change'] == true ||
        profile['force_password_change'] == true;

    if (isAdmin || blocked) {
      await _clearOfflineProfile();
      return profile;
    }

    try {
      final response = await dio.get('subscription/status/');
      final status =
          Map<String, dynamic>.from(response.data as Map);

      final expiry = DateTime.tryParse(
        status['expires_at']?.toString() ?? '',
      );

      final now = DateTime.now().toUtc();

      if (status['active'] != true ||
          expiry == null ||
          !expiry.toUtc().isAfter(now)) {
        await _clearOfflineProfile();
        return profile;
      }

      // Ruxsat belgisi oxirida yoziladi.
      await secure.delete(key: _checkedKey);

      await secure.write(
        key: _profileKey,
        value: jsonEncode(profile),
      );

      await secure.write(
        key: _serverKey,
        value: dio.options.baseUrl,
      );

      await secure.write(
        key: _expiryKey,
        value: expiry.toUtc().toIso8601String(),
      );

      await secure.write(
        key: _checkedKey,
        value: now.toIso8601String(),
      );
    } catch (error) {
      // Tarmoq uzilsa oldingi tasdiqning muddati uzaytirilmaydi.
      // Boshqa xatoda eski offline ruxsat bekor qilinadi.
      if (!isNetworkError(error)) {
        await _clearOfflineProfile();
      }
    }

    return profile;
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response =
        await dio.get(path, queryParameters: query);

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<dynamic>> _getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response =
        await dio.get(path, queryParameters: query);

    return List<dynamic>.from(response.data as List);
  }

  Future<Map<String, dynamic>> _postMap(
    String path,
    Object? data,
  ) async {
    final response = await dio.post(path, data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> _patchMap(
    String path,
    Object? data,
  ) async {
    final response = await dio.patch(path, data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  // Profil va autentifikatsiya.

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) =>
      _patchMap('me/', data);

  Future<Map<String, dynamic>> changeUsername(
    String username,
  ) =>
      _postMap(
        'auth/change-username/',
        {'username': username},
      );

  Future<Map<String, dynamic>> activateAccount(
    String code,
    String password,
  ) =>
      _postMap(
        'auth/activate/',
        {'code': code, 'password': password},
      );

  Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
    String confirmPassword,
  ) =>
      _postMap(
        'auth/change-password/',
        {
          'old_password': oldPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );

  // Tariflar va to‘lovlar.

  Future<List<dynamic>> plans() => _getList('plans/');

  Future<List<dynamic>> payments() => _getList('payments/');

  Future<List<dynamic>> subscriptionHistory() =>
      _getList('subscriptions/history/');

  // Superadmin.

  Future<Map<String, dynamic>> adminDashboard({
    String? start,
    String? end,
  }) =>
      _getMap(
        'admin/dashboard/',
        query: {
          if (start != null) 'start': start,
          if (end != null) 'end': end,
        },
      );

  Future<Map<String, dynamic>> adminUsers({
    int page = 1,
    String? q,
    bool? active,
  }) =>
      _getMap(
        'admin/users/',
        query: {
          'page': page,
          if (q != null && q.isNotEmpty) 'q': q,
          if (active != null) 'active': '$active',
        },
      );

  Future<Map<String, dynamic>> adminUser(
    int id,
    bool active,
  ) =>
      _patchMap(
        'admin/users/$id/',
        {'is_active': active},
      );

  Future<Map<String, dynamic>> adminStores({
    int page = 1,
    String? q,
    bool? active,
  }) =>
      _getMap(
        'admin/stores/',
        query: {
          'page': page,
          if (q != null && q.isNotEmpty) 'q': q,
          if (active != null) 'active': '$active',
        },
      );

  Future<Map<String, dynamic>> adminStore(
    int id,
    bool active,
    String reason,
  ) =>
      _patchMap(
        'admin/stores/',
        {
          'store_id': id,
          'is_active': active,
          'reason': reason,
        },
      );

  Future<List<dynamic>> adminPlans() =>
      _getList('admin/plans/');

  Future<Map<String, dynamic>> saveAdminPlan(
    Map<String, dynamic> data, {
    int? id,
  }) =>
      id == null
          ? _postMap('admin/plans/', data)
          : _patchMap('admin/plans/$id/', data);

  Future<List<dynamic>> adminSubscriptions({
    String? status,
    String? q,
  }) =>
      _getList(
        'admin/subscriptions/',
        query: {
          if (status != null) 'status': status,
          if (q != null && q.isNotEmpty) 'q': q,
        },
      );

  Future<Map<String, dynamic>> adminSubscriptionAction(
    int storeId,
    String action, {
    int months = 1,
    required String reason,
  }) =>
      _postMap(
        'admin/subscriptions/',
        {
          'store_id': storeId,
          'action': action,
          'months': months,
          'reason': reason,
        },
      );

  Future<Map<String, dynamic>> adminPayments({
    int page = 1,
    String? status,
    String? start,
    String? end,
  }) =>
      _getMap(
        'admin/payments/',
        query: {
          'page': page,
          if (status != null) 'status': status,
          if (start != null) 'start': start,
          if (end != null) 'end': end,
        },
      );

  Future<Map<String, dynamic>> adminApprovePayment(
    int id,
    String reason,
  ) =>
      _patchMap(
        'admin/payments/$id/',
        {'action': 'approve', 'reason': reason},
      );

  Future<Map<String, dynamic>> adminAudit({
    int page = 1,
    String? q,
  }) =>
      _getMap(
        'admin/audit/',
        query: {
          'page': page,
          if (q != null && q.isNotEmpty) 'q': q,
        },
      );

  Future<Map<String, dynamic>> adminSystemStatus() =>
      _getMap('admin/system-status/');

  Future<Map<String, dynamic>> createAdminUser(
    String username,
    String storeName,
  ) =>
      _postMap(
        'admin/users/',
        {
          'username': username,
          'store_name': storeName,
        },
      );

  Future<Map<String, dynamic>> issueCredential(
    int userId,
    String purpose,
  ) =>
      _postMap(
        'admin/issue-credential/',
        {
          'user_id': userId,
          'purpose': purpose,
        },
      );

  // Mahsulotlar.

  Future<List<dynamic>> products({String? search}) =>
      _getList(
        'products/',
        query: {
          if (search != null && search.isNotEmpty) 'q': search,
        },
      );

  Future<Map<String, dynamic>?> getProduct(int id) async =>
      _getMap('products/$id/');

  Future<Object> _productBody(
    Map<String, dynamic> payload,
    String? imagePath,
  ) async {
    if (imagePath == null || imagePath.isEmpty) {
      return payload;
    }

    final file = XFile(imagePath);
    final bytes = await file.readAsBytes();

    return FormData.fromMap({
      ...payload,
      'image': MultipartFile.fromBytes(
        bytes,
        filename: file.name,
      ),
    });
  }

  Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> payload, {
    String? imagePath,
  }) async =>
      _postMap(
        'products/',
        await _productBody(payload, imagePath),
      );

  Future<Map<String, dynamic>> updateProduct(
    int id,
    Map<String, dynamic> payload, {
    String? imagePath,
  }) async =>
      _patchMap(
        'products/$id/',
        await _productBody(payload, imagePath),
      );

  Future<void> deleteProduct(int id) async {
    await dio.delete('products/$id/');
  }

  Future<void> archiveProduct(int id) async {
    await dio.post('products/$id/archive/');
  }

  // Toifalar.

  Future<List<dynamic>> getCategories() =>
      _getList('categories/');

  Future<Map<String, dynamic>> createCategory(String name) =>
      _postMap('categories/', {'name': name});

  Future<Map<String, dynamic>> updateCategory(
    int id,
    String name,
  ) =>
      _patchMap('categories/$id/', {'name': name});

  Future<void> deleteCategory(int id) async {
    await dio.delete('categories/$id/');
  }

  // Ombor.

  Future<List<dynamic>> getInventoryMovements({
    int? productId,
  }) =>
      _getList(
        'inventory/movements/',
        query: {
          if (productId != null) 'product_id': productId,
        },
      );

  Future<Map<String, dynamic>> adjustStock(
    int productId,
    String delta,
    String reason,
  ) =>
      _postMap(
        'inventory/adjustments/',
        {
          'product_id': productId,
          'delta': delta,
          'reason': reason,
        },
      );

  // Sotuvlar.

  Future<List<dynamic>> sales() => _getList('sales/');

  Future<Map<String, dynamic>> report() =>
      _getMap('reports/summary/');

  Future<Map<String, dynamic>> checkout(
    Map<String, dynamic> data,
  ) =>
      _postMap('sales/', data);

  Future<Map<String, dynamic>> posCreateSale({
    required List<Map<String, dynamic>> items,
    required double cash,
    required double card,
    required double discount,
    required String operationId,
  }) =>
      _postMap(
        'sales/',
        {
          'operation_id': operationId,
          'items': items,
          'cash': cash.toStringAsFixed(2),
          'card': card.toStringAsFixed(2),
          'discount': discount.toStringAsFixed(2),
        },
      );

  Future<List<dynamic>> posSalesList({
    String? start,
    String? end,
  }) =>
      _getList(
        'sales/',
        query: {
          if (start != null) 'start': start,
          if (end != null) 'end': end,
        },
      );

  // Qarz / nasiya.

  Future<List<dynamic>> debts({
    String? direction,
    String? search,
    String? status,
    String? due,
    String? sort,
    String? start,
    String? end,
  }) =>
      _getList(
        'debts/',
        query: {
          if (direction != null) 'direction': direction,
          if (search != null && search.isNotEmpty) 'q': search,
          if (status != null) 'status': status,
          if (due != null) 'due': due,
          if (sort != null) 'sort': sort,
          if (start != null) 'start': start,
          if (end != null) 'end': end,
        },
      );

  Future<Map<String, dynamic>> createDebt(
    Map<String, dynamic> data,
  ) =>
      _postMap('debts/', data);

  Future<Map<String, dynamic>> debtDetail(int id) =>
      _getMap('debts/$id/');

  Future<Map<String, dynamic>> updateDebt(
    int id, {
    String? note,
    String? dueDate,
    bool clearDueDate = false,
  }) =>
      _patchMap(
        'debts/$id/',
        {
          if (note != null) 'note': note,
          if (clearDueDate)
            'due_date': null
          else if (dueDate != null)
            'due_date': dueDate,
        },
      );

  Future<Map<String, dynamic>> recordDebtPayment(
    int id, {
    required String amount,
    required String method,
    required String paidOn,
    String note = '',
  }) =>
      _postMap(
        'debts/$id/payments/',
        {
          'operation_id': const Uuid().v4(),
          'amount': amount,
          'method': method,
          'paid_on': paidOn,
          'note': note,
        },
      );

  // Offline sinxronlash.

  Future<Map<String, dynamic>> syncPush(
    List<Map<String, dynamic>> operations,
  ) =>
      _postMap(
        'sync/push/',
        {'operations': operations},
      );
}