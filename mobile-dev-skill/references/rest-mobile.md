# REST API Integration on Mobile

## Response envelope pattern (all platforms)
Design your API to return a consistent envelope:
```json
{
  "success": true,
  "data": { ... },
  "error": null,
  "meta": { "page": 1, "total": 100 }
}
```
Model this on the client side to avoid scattered null checks.

## Flutter (Dio + Either pattern)
```dart
typedef ApiResult<T> = Either<Failure, T>;

abstract class Failure {
  final String message;
  const Failure(this.message);
}
class ServerFailure extends Failure { const ServerFailure(super.message); }
class NetworkFailure extends Failure { const NetworkFailure() : super('No internet connection'); }

// Repository impl
Future<ApiResult<List<Article>>> getArticles() async {
  try {
    final response = await _client.get('/articles');
    final articles = (response.data['data'] as List)
        .map((e) => Article.fromJson(e))
        .toList();
    return Right(articles);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionError) return const Left(NetworkFailure());
    return Left(ServerFailure(e.response?.data['error'] ?? 'Server error'));
  }
}
```

## Kotlin (Retrofit + Result)
```kotlin
interface ArticleApi {
    @GET("articles")
    suspend fun getArticles(@Query("page") page: Int = 1): Response<ApiResponse<List<ArticleDto>>>
}

data class ApiResponse<T>(val success: Boolean, val data: T?, val error: String?)

// Repository
suspend fun getArticles(): Result<List<Article>> = runCatching {
    val response = api.getArticles()
    if (!response.isSuccessful) throw HttpException(response)
    response.body()?.data?.map { it.toDomain() } ?: emptyList()
}
```

## Swift (async/await + Result)
```swift
func getArticles(page: Int = 1) async -> Result<[Article], APIError> {
    do {
        let dto: ApiResponse<[ArticleDTO]> = try await client.get("/articles?page=\(page)")
        guard dto.success, let data = dto.data else {
            return .failure(.serverError(dto.error ?? "Unknown"))
        }
        return .success(data.map { $0.toDomain() })
    } catch {
        return .failure(.networkError(error.localizedDescription))
    }
}
```

## React Native (Axios + Zustand)
```typescript
// api/articles.ts
export const articlesApi = {
  getAll: async (page = 1): Promise<Article[]> => {
    const { data } = await api.get<ApiResponse<Article[]>>('/articles', { params: { page } });
    if (!data.success) throw new Error(data.error ?? 'Server error');
    return data.data!;
  },
};

// features/articles/store.ts
interface ArticlesState {
  articles: Article[];
  page: number;
  hasMore: boolean;
  loading: boolean;
  fetchMore: () => Promise<void>;
}
export const useArticlesStore = create<ArticlesState>((set, get) => ({
  articles: [], page: 1, hasMore: true, loading: false,
  fetchMore: async () => {
    if (!get().hasMore || get().loading) return;
    set({ loading: true });
    const next = await articlesApi.getAll(get().page);
    set((s) => ({
      articles: [...s.articles, ...next],
      page: s.page + 1,
      hasMore: next.length > 0,
      loading: false,
    }));
  },
}));
```

## Auth token refresh (all platforms)
Implement a request queue to avoid multiple simultaneous refresh calls:

```
1. Request fails with 401
2. Check if refresh is already in progress
   - If yes: queue this request
   - If no: start refresh
3. On refresh success: replay queued requests with new token
4. On refresh failure: clear session → navigate to login
```

Flutter/Dio: use `QueuedInterceptorsWrapper`
Kotlin: use OkHttp `Authenticator` interface
Swift: use a `refreshTask: Task<String, Error>?` singleton pattern
React Native: use Axios interceptor with a `refreshPromise` variable

## Pagination patterns
- **Offset**: `?page=1&limit=20` — simple, but inconsistent if items are added/removed
- **Cursor**: `?after=eyJpZCI6MTAwfQ==` — stable, preferred for feeds
- **Keyset**: `?after_id=100` — fast for large datasets with indexed columns
