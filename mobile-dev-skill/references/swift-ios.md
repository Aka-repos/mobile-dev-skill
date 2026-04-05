# Swift / iOS Reference

## Project Structure (MVVM + SwiftUI)

```
MyApp/
├── App/
│   ├── MyApp.swift            # @main entry point
│   └── AppCoordinator.swift   # Root navigation
├── Core/
│   ├── Network/               # URLSession / Alamofire setup
│   ├── Storage/               # Keychain, UserDefaults wrappers
│   └── Extensions/            # String+, Date+, etc.
├── Domain/
│   ├── Models/                # Codable structs (entities)
│   ├── Repositories/          # Protocols
│   └── UseCases/
├── Data/
│   ├── Remote/
│   │   ├── APIClient.swift
│   │   └── DTOs/
│   └── Repositories/          # Protocol implementations
└── Presentation/
    ├── Auth/
    │   ├── AuthView.swift
    │   └── AuthViewModel.swift
    └── Shared/
        └── Components/        # Reusable SwiftUI views
```

## ViewModel pattern (ObservableObject)
```swift
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var state: AuthState = .idle
    
    private let loginUseCase: LoginUseCase
    
    init(loginUseCase: LoginUseCase) {
        self.loginUseCase = loginUseCase
    }
    
    func login(email: String, password: String) {
        state = .loading
        Task {
            do {
                let user = try await loginUseCase.execute(email: email, password: password)
                state = .success(user)
            } catch {
                state = .failure(error.localizedDescription)
            }
        }
    }
}

enum AuthState {
    case idle, loading
    case success(User)
    case failure(String)
}
```

## SwiftUI View consuming ViewModel
```swift
struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel(loginUseCase: .live)
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            SecureField("Password", text: $password)
            
            Button("Login") {
                viewModel.login(email: email, password: password)
            }
            .disabled(viewModel.state == .loading)
            
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .failure(let msg):
                Text(msg).foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
        .padding()
    }
}
```

## Networking (async/await + URLSession)
```swift
struct APIClient {
    private let baseURL: URL
    private let session: URLSession
    
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    func get<T: Decodable>(_ path: String, token: String? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.timeoutInterval = 30
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum APIError: Error {
    case badResponse
    case decodingFailed
}
```

## Dependency Injection (simple factory pattern)
```swift
extension LoginUseCase {
    static var live: LoginUseCase {
        LoginUseCase(repository: AuthRepositoryImpl(client: APIClient(baseURL: Config.apiURL)))
    }
    static var preview: LoginUseCase {
        LoginUseCase(repository: MockAuthRepository())
    }
}
```

## Keychain wrapper (for tokens)
```swift
struct Keychain {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
    }
}
```

## Common pitfalls
- **Retain cycles**: always use `[weak self]` in closures that capture self
- **Force unwrapping**: avoid `!` — use `guard let` or `if let`
- **UI on main thread**: any `@Published` mutation must happen on `@MainActor` (or `DispatchQueue.main.async`)
- **Combine vs async/await**: prefer `async/await` for new code, Combine when working with existing reactive chains
- **@StateObject vs @ObservedObject**: use `@StateObject` for objects the view owns, `@ObservedObject` for injected ones

## Key packages (Swift Package Manager)
```
// Alamofire (networking)
https://github.com/Alamofire/Alamofire — 5.9.0

// Firebase iOS SDK
https://github.com/firebase/firebase-ios-sdk — 10.x

// Kingfisher (async image loading)
https://github.com/onevcat/Kingfisher — 7.x

// SwiftLint
https://github.com/realm/SwiftLint — dev only
```
