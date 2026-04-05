# Kotlin / Android Reference

## Project Structure (MVVM + Clean Architecture)

```
app/src/main/java/com/example/app/
├── di/                        # Hilt modules
├── core/
│   ├── network/               # Retrofit setup, interceptors
│   ├── utils/                 # Extensions, helpers
│   └── base/                  # BaseViewModel, BaseFragment
├── data/
│   ├── remote/
│   │   ├── api/               # Retrofit interfaces
│   │   └── dto/               # Data Transfer Objects
│   ├── local/
│   │   ├── db/                # Room database
│   │   └── dao/               # Room DAOs
│   └── repository/            # Repository implementations
├── domain/
│   ├── model/                 # Domain entities
│   ├── repository/            # Repository interfaces
│   └── usecase/               # Use cases
└── presentation/
    ├── ui/
    │   ├── auth/
    │   │   ├── AuthFragment.kt
    │   │   └── AuthViewModel.kt
    │   └── home/
    └── adapter/               # RecyclerView adapters
```

## ViewModel + StateFlow pattern
```kotlin
@HiltViewModel
class AuthViewModel @Inject constructor(
    private val loginUseCase: LoginUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow<AuthUiState>(AuthUiState.Idle)
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    fun login(email: String, password: String) {
        viewModelScope.launch {
            _uiState.value = AuthUiState.Loading
            loginUseCase(email, password)
                .onSuccess { user -> _uiState.value = AuthUiState.Success(user) }
                .onFailure { e -> _uiState.value = AuthUiState.Error(e.message ?: "Unknown error") }
        }
    }
}

sealed class AuthUiState {
    object Idle : AuthUiState()
    object Loading : AuthUiState()
    data class Success(val user: User) : AuthUiState()
    data class Error(val message: String) : AuthUiState()
}
```

## Collecting StateFlow in Fragment
```kotlin
viewLifecycleOwner.lifecycleScope.launch {
    repeatOnLifecycle(Lifecycle.State.STARTED) {
        viewModel.uiState.collect { state ->
            when (state) {
                is AuthUiState.Loading -> showLoading()
                is AuthUiState.Success -> navigateToHome()
                is AuthUiState.Error -> showError(state.message)
                else -> Unit
            }
        }
    }
}
```

## Retrofit setup
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides @Singleton
    fun provideOkHttpClient(authInterceptor: AuthInterceptor): OkHttpClient =
        OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .build()

    @Provides @Singleton
    fun provideRetrofit(client: OkHttpClient): Retrofit =
        Retrofit.Builder()
            .baseUrl(BuildConfig.API_BASE_URL)
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
}

class AuthInterceptor @Inject constructor(
    private val tokenStore: TokenStore
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val token = tokenStore.getToken()
        val request = chain.request().newBuilder()
            .apply { if (token != null) addHeader("Authorization", "Bearer $token") }
            .build()
        return chain.proceed(request)
    }
}
```

## Jetpack Compose basics
```kotlin
@Composable
fun LoginScreen(viewModel: AuthViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("Email") })
        OutlinedTextField(value = password, onValueChange = { password = it },
            label = { Text("Password") }, visualTransformation = PasswordVisualTransformation())
        Button(
            onClick = { viewModel.login(email, password) },
            enabled = uiState !is AuthUiState.Loading
        ) { Text("Login") }
        when (uiState) {
            is AuthUiState.Loading -> CircularProgressIndicator()
            is AuthUiState.Error -> Text((uiState as AuthUiState.Error).message, color = Color.Red)
            else -> Unit
        }
    }
}
```

## Key dependencies (build.gradle)
```kotlin
dependencies {
    // Lifecycle
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    // Hilt
    implementation("com.google.dagger:hilt-android:2.50")
    kapt("com.google.dagger:hilt-compiler:2.50")
    // Retrofit
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    // Compose
    implementation(platform("androidx.compose:compose-bom:2024.02.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    // Navigation Compose
    implementation("androidx.navigation:navigation-compose:2.7.7")
    // Room
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")
}
```

## Route-Screen pattern (Compose)
```kotlin
// Route: owns ViewModel + navigation callbacks — never passes viewModel down
@Composable
fun HomeRoute(
    onArticleClick: (String) -> Unit,
    viewModel: HomeViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    HomeScreen(uiState = uiState, onArticleClick = onArticleClick)
}

// Screen: pure UI, no ViewModel, fully previewable
@Composable
fun HomeScreen(
    uiState: HomeUiState,
    onArticleClick: (String) -> Unit
) {
    when (uiState) {
        is HomeUiState.Loading -> CircularProgressIndicator()
        is HomeUiState.Success -> ArticleList(uiState.articles, onArticleClick)
        is HomeUiState.Error -> ErrorMessage(uiState.message)
    }
}
```

## Type-safe Navigation (Navigation 2.8+)
```kotlin
// Define routes as serializable objects/classes
@Serializable object HomeRoute
@Serializable data class ArticleRoute(val id: String)

// NavGraph extension
fun NavGraphBuilder.homeGraph(onArticleClick: (String) -> Unit) {
    composable<HomeRoute> { HomeRoute(onArticleClick) }
    composable<ArticleRoute> { backStack ->
        val route: ArticleRoute = backStack.toRoute()
        ArticleRoute(articleId = route.id)
    }
}

// Navigate type-safely
navController.navigate(ArticleRoute(id = article.id))
```

## Offline-first (Room as source of truth)
```kotlin
// Repository always reads from Room; syncs from network in background
class OfflineFirstArticleRepository @Inject constructor(
    private val dao: ArticleDao,
    private val api: ArticleApi,
    private val workManager: WorkManager
) : ArticleRepository {

    override fun getArticles(): Flow<List<Article>> = dao.getAll().map { it.map(ArticleEntity::toDomain) }

    override suspend fun sync() {
        val dtos = api.getArticles()
        dao.upsertAll(dtos.map(ArticleDto::toEntity))
    }
}

// Periodic sync via WorkManager
class SyncWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result {
        return try {
            articleRepository.sync()
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
```

## Adaptive layouts (WindowSizeClass)
```kotlin
@Composable
fun AppScaffold(windowSizeClass: WindowSizeClass) {
    val useNavRail = windowSizeClass.widthSizeClass >= WindowWidthSizeClass.Medium
    if (useNavRail) {
        Row {
            AppNavRail(destinations = topLevelDestinations)
            AppNavHost(modifier = Modifier.weight(1f))
        }
    } else {
        Scaffold(bottomBar = { AppBottomBar(destinations = topLevelDestinations) }) { padding ->
            AppNavHost(modifier = Modifier.padding(padding))
        }
    }
}
```

## Multi-module structure (quick reference)
```
app/
feature/
  :home:api      # Public interfaces/models only — no impl details
  :home:impl     # Implementation, depends on :home:api + core:*
core/
  :data          # Repository implementations
  :database      # Room setup, DAOs, entities
  :network       # Retrofit, DTOs
  :model         # Pure domain models — no dependencies
  :ui            # Shared composables, theme
  :testing       # Test doubles, TestDispatcherRule
```
**Dependency rule**: `feature:impl` → `feature:api` + `core:*` only. Never `feature → feature`.

## Testing with test doubles (no mocking libraries)
```kotlin
// Implement the same interface your production code uses
class TestArticleRepository : ArticleRepository {
    private val articles = MutableStateFlow<List<Article>>(emptyList())
    fun emit(items: List<Article>) { articles.value = items }
    override fun getArticles(): Flow<List<Article>> = articles
    override suspend fun sync() { /* no-op in tests */ }
}

// ViewModel test with Turbine + TestDispatcherRule
@Test
fun `loading state emitted then success`() = runTest {
    val repo = TestArticleRepository()
    val vm = HomeViewModel(repo)
    repo.emit(listOf(Article("1", "Title")))
    vm.uiState.test {
        assertIs<HomeUiState.Loading>(awaitItem())
        assertIs<HomeUiState.Success>(awaitItem())
    }
}
```

## Common pitfalls
- Always use `lifecycleScope` / `viewModelScope` — never `GlobalScope`
- Collect flows with `repeatOnLifecycle(STARTED)` to avoid leaks when app is backgrounded
- Room queries must run on a background thread (Room's Kotlin extensions handle this with `suspend`)
- Don't reference `Activity` or `Fragment` from `ViewModel` — causes memory leaks
- Route-Screen split: never pass `ViewModel` as a parameter to a Screen composable
- Multi-module: don't create `:feature:impl → :feature:impl` cross-dependencies
