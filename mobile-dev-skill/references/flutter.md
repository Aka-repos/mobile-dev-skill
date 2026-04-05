# Flutter / Dart Reference

## Project Structure (recommended)

```
lib/
├── main.dart
├── app/
│   ├── app.dart              # MaterialApp / root widget
│   └── routes.dart           # Named routes or GoRouter config
├── core/
│   ├── constants/            # API URLs, keys, enums
│   ├── errors/               # Failure classes, exceptions
│   ├── network/              # Dio/http client setup
│   └── utils/                # Extensions, helpers
├── features/
│   └── auth/
│       ├── data/
│       │   ├── datasources/  # Remote & local datasources
│       │   ├── models/       # JSON serializable models
│       │   └── repositories/ # Implementation
│       ├── domain/
│       │   ├── entities/     # Pure Dart classes
│       │   ├── repositories/ # Abstract interfaces
│       │   └── usecases/     # Single-responsibility use cases
│       └── presentation/
│           ├── bloc/         # or provider/, riverpod/
│           ├── pages/
│           └── widgets/
└── shared/
    ├── widgets/              # Reusable UI components
    └── theme/                # AppTheme, colors, text styles
```

## State Management

### BLoC (recommended for complex apps)
```dart
// event
abstract class AuthEvent {}
class LoginRequested extends AuthEvent {
  final String email, password;
  LoginRequested({required this.email, required this.password});
}

// state
abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthSuccess extends AuthState { final User user; AuthSuccess(this.user); }
class AuthFailure extends AuthState { final String message; AuthFailure(this.message); }

// bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  AuthBloc({required this.loginUseCase}) : super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await loginUseCase(email: event.email, password: event.password);
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthSuccess(user)),
    );
  }
}
```

### Riverpod (recommended for simpler apps)
```dart
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(() => AuthNotifier());

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async => null;

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).login(email, password));
  }
}
```

## Navigation

### GoRouter (recommended)
```dart
final router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/home', builder: (ctx, state) => const HomePage()),
    GoRoute(
      path: '/article/:id',
      builder: (ctx, state) => ArticlePage(id: state.pathParameters['id']!),
    ),
  ],
  redirect: (ctx, state) {
    final isLoggedIn = /* check auth */;
    if (!isLoggedIn && state.matchedLocation != '/login') return '/login';
    return null;
  },
);
```

## Networking (Dio)
```dart
class ApiClient {
  late final Dio _dio;

  ApiClient(String baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ))
      ..interceptors.add(LogInterceptor(responseBody: true))
      ..interceptors.add(_authInterceptor());
  }

  Interceptor _authInterceptor() => InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await SecureStorage.getToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
  );

  Future<T> get<T>(String path, T Function(dynamic) fromJson) async {
    final response = await _dio.get(path);
    return fromJson(response.data);
  }
}
```

## Common Fixes

### RenderFlex overflow
```dart
// Bad
Row(children: [Text('Very long text...'), Icon(Icons.arrow)])

// Good
Row(children: [Expanded(child: Text('Very long text...')), Icon(Icons.arrow)])
```

### BuildContext across async gap
```dart
// Bad
Future<void> save() async {
  await repository.save(data);
  Navigator.of(context).pop(); // context may be invalid
}

// Good
Future<void> save() async {
  await repository.save(data);
  if (!mounted) return;
  Navigator.of(context).pop();
}
```

### ListView inside Column (unbounded height)
```dart
// Bad
Column(children: [ListView(...)])

// Good
Column(children: [Expanded(child: ListView(...))])
// or
ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics(), ...)
```

## pubspec.yaml essentials
```yaml
dependencies:
  flutter_bloc: ^8.1.3
  go_router: ^13.0.0
  dio: ^5.4.0
  get_it: ^7.6.7          # dependency injection
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

dev_dependencies:
  build_runner: ^2.4.8
  freezed: ^2.4.6
  json_serializable: ^6.7.1
  flutter_lints: ^3.0.0
  bloc_test: ^9.1.5
```
