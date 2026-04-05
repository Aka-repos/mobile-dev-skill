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

## Common pitfalls
- Always use `lifecycleScope` / `viewModelScope` — never `GlobalScope`
- Collect flows with `repeatOnLifecycle(STARTED)` to avoid leaks when app is backgrounded
- Room queries must run on a background thread (Room's Kotlin extensions handle this with `suspend`)
- Don't reference `Activity` or `Fragment` from `ViewModel` — causes memory leaks
