import 'dart:async';
import 'package:uuid/uuid.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

String get _apiBaseUrl {
  if (_configuredApiBaseUrl.trim().isNotEmpty) {
    return _configuredApiBaseUrl;
  }
  if (kReleaseMode) return 'https://example.invalid/api/v1/';
  if (kIsWeb) return 'http://localhost:8000/api/v1/';
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android emulator: 10.0.2.2 — host mashina.
    // Haqiqiy qurilmalarda API_BASE_URL yoki `adb reverse tcp:8000 tcp:8000` kerak.
    return 'http://10.0.2.2:8000/api/v1/';
  }
  return 'http://127.0.0.1:8000/api/v1/';
}

class Api {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: _apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
    ),
  );

  final FlutterSecureStorage secure = const FlutterSecureStorage();

  // 401 refresh uchun: bir vaqtda faqat bitta refresh bajarilsin.
  // Parallel so'rovlar birinchi refresh tugaguncha kutadi.
  bool _refreshing = false;
  Completer<bool>? _refreshCompleter;

  /// Logout callback — token yangilash xato berganda chaqiriladi.
  /// Ilovada [app.dart] ichida o'rnatiladi.
  void Function()? onLogout;

  // Interceptordan chetda qolishi kerak bo'lgan yo'llar (cheksiz sikl oldini olish uchun).
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
          final token = await secure.read(key: 'access');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final response = error.response;
          if (response == null || response.statusCode != 401) {
            handler.next(error);
            return;
          }

          // Exempt yo'llarni tekshir — cheksiz sikl oldini olish.
          final path =
              error.requestOptions.path.replaceAll(RegExp(r'^/+'), '');
          if (_exemptPaths.any((e) => path.startsWith(e))) {
            handler.next(error);
            return;
          }

          // Agar refresh allaqachon bajarilmoqda bo'lsa — birinchi natijani kutamiz.
          if (_refreshing) {
            final ok = await _refreshCompleter!.future;
            if (!ok) {
              handler.next(error);
              return;
            }
            try {
              final retried = await _retry(error.requestOptions);
              handler.resolve(retried);
            } catch (e) {
              handler.next(error);
            }
            return;
          }

          // Refresh jarayonini boshlash.
          _refreshing = true;
          _refreshCompleter = Completer<bool>();

          final refreshed = await _doRefresh();
          _refreshCompleter!.complete(refreshed);
          _refreshing = false;
          _refreshCompleter = null;

          if (!refreshed) {
            // Refresh xato berdi — tokenlarni o'chirib login ekraniga qaytish.
            await secure.deleteAll();
            onLogout?.call();
            handler.next(error);
            return;
          }

          // Muvaffaqiyatli refresh — asl so'rovni yangi token bilan qayta yuborish.
          try {
            final retried = await _retry(error.requestOptions);
            handler.resolve(retried);
          } catch (e) {
            handler.next(error);
          }
        },
      ),
    );
  }

  /// Refresh tokenni ishlatib yangi access token olish.
  Future<bool> _doRefresh() async {
    try {
      final refresh = await secure.read(key: 'refresh');
      if (refresh == null || refresh.trim().isEmpty) return false;

      final r = await dio
          .post(
            'auth/token/refresh/',
            data: {'refresh': refresh},
          )
          .timeout(const Duration(seconds: 8));

      await secure.write(key: 'access', value: r.data['access'] as String);
      if (r.data['refresh'] != null) {
        await secure.write(
            key: 'refresh', value: r.data['refresh'] as String);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Asl so'rovni yangilangan token bilan qayta yuborish.
  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final newToken = await secure.read(key: 'access');
    final options = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        if (newToken != null) 'Authorization': 'Bearer $newToken',
      },
    );
    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  Future<bool> login(String username, String password) async {
    // Eski tokenlarni tozalash.
    await secure.delete(key: 'access');
    await secure.delete(key: 'refresh');

    // Login uchun interceptor'siz toza so'rov.
    final r = await dio.post(
      'auth/login/',
      data: {
        'username': username,
        'password': password,
      },
      options: Options(
        headers: {}, // Authorization header kerak emas.
      ),
    );
    await secure.write(key: 'access', value: r.data['access'] as String);
    await secure.write(key: 'refresh', value: r.data['refresh'] as String);
    return true;
  }

  Future<bool> restore() async {
    final refresh = await secure.read(key: 'refresh');
    if (refresh == null || refresh.trim().isEmpty) return false;

    try {
      final r = await dio
          .post('auth/token/refresh/', data: {'refresh': refresh})
          .timeout(const Duration(seconds: 4));

      await secure.write(key: 'access', value: r.data['access'] as String);
      if (r.data['refresh'] != null) {
        await secure.write(
            key: 'refresh', value: r.data['refresh'] as String);
      }

      await dio.get('me/').timeout(const Duration(seconds: 4));
      return true;
    } on TimeoutException catch (_) {
      return false;
    } on DioException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final token = await secure.read(key: 'refresh');
      if (token != null) {
        await dio.post('auth/logout/', data: {'refresh': token});
      }
    } finally {
      await secure.deleteAll();
    }
  }

  Future<Map<String, dynamic>> me() async {
    final r = await dio.get('me/');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(
          (await dio.patch('me/', data: data)).data as Map);

  Future<Map<String, dynamic>> changeUsername(String username) async =>
      Map<String, dynamic>.from((await dio
              .post('auth/change-username/', data: {'username': username}))
          .data as Map);

  Future<List<dynamic>> plans() async =>
      (await dio.get('plans/')).data as List<dynamic>;

  Future<List<dynamic>> payments() async =>
      (await dio.get('payments/')).data as List<dynamic>;

  Future<List<dynamic>> subscriptionHistory() async =>
      (await dio.get('subscriptions/history/')).data as List<dynamic>;

  Future<Map<String, dynamic>> adminDashboard(
          {String? start, String? end}) async =>
      Map<String, dynamic>.from((await dio.get('admin/dashboard/',
              queryParameters: {
            if (start != null) 'start': start,
            if (end != null) 'end': end
          }))
          .data as Map);

  Future<Map<String, dynamic>> adminUsers(
      {int page = 1, String? q, bool? active}) async {
    final r = await dio.get('admin/users/', queryParameters: {
      'page': page,
      if (q != null && q.isNotEmpty) 'q': q,
      if (active != null) 'active': '$active'
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> adminUser(int id, bool active) async =>
      Map<String, dynamic>.from(
          (await dio.patch('admin/users/$id/', data: {'is_active': active}))
              .data as Map);

  Future<Map<String, dynamic>> adminStores(
          {int page = 1, String? q, bool? active}) async =>
      Map<String, dynamic>.from(
          (await dio.get('admin/stores/', queryParameters: {
        'page': page,
        if (q != null && q.isNotEmpty) 'q': q,
        if (active != null) 'active': '$active'
      }))
              .data as Map);

  Future<Map<String, dynamic>> adminStore(
          int id, bool active, String reason) async =>
      Map<String, dynamic>.from((await dio.patch('admin/stores/',
              data: {'store_id': id, 'is_active': active, 'reason': reason}))
          .data as Map);

  Future<List<dynamic>> adminPlans() async =>
      (await dio.get('admin/plans/')).data as List<dynamic>;

  Future<Map<String, dynamic>> saveAdminPlan(Map<String, dynamic> data,
          {int? id}) async =>
      Map<String, dynamic>.from((await (id == null
              ? dio.post('admin/plans/', data: data)
              : dio.patch('admin/plans/$id/', data: data)))
          .data as Map);

  Future<List<dynamic>> adminSubscriptions(
          {String? status, String? q}) async =>
      (await dio.get('admin/subscriptions/', queryParameters: {
        if (status != null) 'status': status,
        if (q != null && q.isNotEmpty) 'q': q,
      }))
          .data as List<dynamic>;

  Future<Map<String, dynamic>> adminSubscriptionAction(
          int storeId, String action,
          {int months = 1, required String reason}) async =>
      Map<String, dynamic>.from((await dio.post('admin/subscriptions/', data: {
        'store_id': storeId,
        'action': action,
        'months': months,
        'reason': reason
      }))
          .data as Map);

  Future<Map<String, dynamic>> adminPayments(
          {int page = 1, String? status, String? start, String? end}) async =>
      Map<String, dynamic>.from(
          (await dio.get('admin/payments/', queryParameters: {
        'page': page,
        if (status != null) 'status': status,
        if (start != null) 'start': start,
        if (end != null) 'end': end
      }))
              .data as Map);

  Future<Map<String, dynamic>> adminApprovePayment(
          int id, String reason) async =>
      Map<String, dynamic>.from((await dio.patch('admin/payments/$id/',
              data: {'action': 'approve', 'reason': reason}))
          .data as Map);

  Future<Map<String, dynamic>> adminAudit({int page = 1, String? q}) async =>
      Map<String, dynamic>.from((await dio.get('admin/audit/',
              queryParameters: {
            'page': page,
            if (q != null && q.isNotEmpty) 'q': q
          }))
          .data as Map);

  Future<Map<String, dynamic>> adminSystemStatus() async =>
      Map<String, dynamic>.from(
          (await dio.get('admin/system-status/')).data as Map);

  Future<Map<String, dynamic>> createAdminUser(
    String username,
    String storeName,
  ) async {
    final r = await dio.post('admin/users/', data: {
      'username': username,
      'store_name': storeName,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> issueCredential(
      int userId, String purpose) async {
    final r = await dio.post('admin/issue-credential/', data: {
      'user_id': userId,
      'purpose': purpose,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> activateAccount(
      String code, String password) async {
    // Aktivatsiya uchun Authorization header kerak emas.
    final r = await dio.post(
      'auth/activate/',
      data: {
        'code': code,
        'password': password,
      },
      options: Options(
        headers: {}, // Authorization header kerak emas.
      ),
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> changePassword(
      String oldPassword, String newPassword, String confirmPassword) async {
    final r = await dio.post('auth/change-password/', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ─── Mahsulotlar API ──────────────────────────────────────────────────────

  Future<List<dynamic>> products({String? search}) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) {
      queryParams['q'] = search;
    }
    final r = await dio.get('products/', queryParameters: queryParams);
    return r.data as List<dynamic>;
  }

  Future<Map<String, dynamic>?> getProduct(int id) async {
    try {
      final r = await dio.get('products/$id/');
      return Map<String, dynamic>.from(r.data as Map);
    } catch (e) {
      rethrow; // HTTP xatolarni mahsulot topilmadi deb yashirmaymiz.
    }
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> payload,
      {String? imagePath}) async {
    final body = await _productBody(payload, imagePath);
    final r = await dio.post('products/', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateProduct(
      int id, Map<String, dynamic> payload,
      {String? imagePath}) async {
    final body = await _productBody(payload, imagePath);
    final r = await dio.patch('products/$id/', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Object> _productBody(
      Map<String, dynamic> payload, String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return payload;
    final file = XFile(imagePath);
    final bytes = await file.readAsBytes();
    return FormData.fromMap({
      ...payload,
      'image': MultipartFile.fromBytes(bytes, filename: file.name),
    });
  }

  Future<void> deleteProduct(int id) async {
    await dio.delete('products/$id/');
  }

  Future<void> archiveProduct(int id) async {
    await dio.post('products/$id/archive/');
  }

  // ─── Toifalar API ────────────────────────────────────────────────────────

  Future<List<dynamic>> getCategories() async {
    final r = await dio.get('categories/');
    return r.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCategory(String name) async {
    final r = await dio.post('categories/', data: {'name': name});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateCategory(int id, String name) async {
    final r = await dio.patch('categories/$id/', data: {'name': name});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> deleteCategory(int id) async {
    await dio.delete('categories/$id/');
  }

  // ─── Ombor API ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getInventoryMovements({int? productId}) async {
    final r = await dio.get('inventory/movements/');
    return r.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> adjustStock(
      int productId, String delta, String reason) async {
    final r = await dio.post('inventory/adjustments/', data: {
      'product_id': productId,
      'delta': delta,
      'reason': reason,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ─── Sotuvlar API ────────────────────────────────────────────────────────

  Future<List<dynamic>> sales() async =>
      (await dio.get('sales/')).data as List<dynamic>;

  Future<Map<String, dynamic>> report() async =>
      Map<String, dynamic>.from((await dio.get('reports/summary/')).data);

  Future<Map<String, dynamic>> checkout(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from((await dio.post('sales/', data: data)).data);

  // ─── Kassa (POS) API ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> posCreateSale({
    required List<Map<String, dynamic>> items,
    required double cash,
    required double card,
    required double discount,
    required String operationId,
  }) async {
    final r = await dio.post('sales/', data: {
      'operation_id': operationId,
      'items': items,
      'cash': cash.toStringAsFixed(2),
      'card': card.toStringAsFixed(2),
      'discount': discount.toStringAsFixed(2),
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<dynamic>> posSalesList({String? start, String? end}) async {
    final r = await dio.get('sales/', queryParameters: {
      if (start != null) 'start': start,
      if (end != null) 'end': end,
    });
    return r.data as List<dynamic>;
  }

  // ─── Qarz (Nasiya) API ───────────────────────────────────────────────────

  Future<List<dynamic>> debts({
    String? direction,
    String? search,
    String? status,
    String? due,
    String? sort,
    String? start,
    String? end,
  }) async =>
      (await dio.get('debts/', queryParameters: {
        if (direction != null) 'direction': direction,
        if (search != null && search.isNotEmpty) 'q': search,
        if (status != null) 'status': status,
        if (due != null) 'due': due,
        if (sort != null) 'sort': sort,
        if (start != null) 'start': start,
        if (end != null) 'end': end,
      }))
          .data as List<dynamic>;

  Future<Map<String, dynamic>> createDebt(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(
          (await dio.post('debts/', data: data)).data as Map);

  Future<Map<String, dynamic>> debtDetail(int id) async =>
      Map<String, dynamic>.from((await dio.get('debts/$id/')).data as Map);

  Future<Map<String, dynamic>> updateDebt(int id,
          {String? note, String? dueDate, bool clearDueDate = false}) async =>
      Map<String, dynamic>.from((await dio.patch('debts/$id/', data: {
        if (note != null) 'note': note,
        if (clearDueDate)
          'due_date': null
        else if (dueDate != null)
          'due_date': dueDate,
      }))
          .data as Map);

  Future<Map<String, dynamic>> recordDebtPayment(
    int id, {
    required String amount,
    required String method,
    required String paidOn,
    String note = '',
  }) async =>
      Map<String, dynamic>.from((await dio.post('debts/$id/payments/', data: {
        'operation_id': const Uuid().v4(),
        'amount': amount,
        'method': method,
        'paid_on': paidOn,
        'note': note,
      }))
          .data as Map);

  // ─── Sinxronlash API ─────────────────────────────────────────────────────

  /// Offline operatsiyalarni serverga yuborish.
  /// Qaytadi: {results: [{operation_id, status: 'ack'|'conflict', ...}]}
  Future<Map<String, dynamic>> syncPush(
      List<Map<String, dynamic>> operations) async {
    final r =
        await dio.post('sync/push/', data: {'operations': operations});
    return Map<String, dynamic>.from(r.data as Map);
  }
}
