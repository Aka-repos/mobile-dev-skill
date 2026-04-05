# Firebase on Mobile Reference

## Auth patterns

### Flutter (firebase_auth)
```dart
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  // Anonymous → linked account upgrade
  Future<UserCredential> linkWithEmail(String email, String password) {
    final credential = EmailAuthProvider.credential(email: email, password: password);
    return _auth.currentUser!.linkWithCredential(credential);
  }
}

// Listen to auth state in root widget
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const SplashScreen();
    return snapshot.hasData ? const HomeScreen() : const LoginScreen();
  },
)
```

### Kotlin (Firebase Android SDK)
```kotlin
class FirebaseAuthRepository @Inject constructor() {
    private val auth = FirebaseAuth.getInstance()

    fun getCurrentUser(): FirebaseUser? = auth.currentUser

    suspend fun login(email: String, password: String): Result<FirebaseUser> =
        runCatching {
            auth.signInWithEmailAndPassword(email, password).await().user!!
        }

    fun signOut() = auth.signOut()
    
    fun authStateFlow(): Flow<FirebaseUser?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { trySend(it.currentUser) }
        auth.addAuthStateListener(listener)
        awaitClose { auth.removeAuthStateListener(listener) }
    }
}
```

### Swift (Firebase iOS SDK)
```swift
final class FirebaseAuthService {
    private let auth = Auth.auth()

    var currentUser: User? { auth.currentUser }

    func login(email: String, password: String) async throws -> User {
        let result = try await auth.signIn(withEmail: email, password: password)
        return result.user
    }

    func signOut() throws { try auth.signOut() }

    func authStateStream() -> AsyncStream<User?> {
        AsyncStream { continuation in
            let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user)
            }
            continuation.onTermination = { _ in Auth.auth().removeStateDidChangeListener(handle) }
        }
    }
}
```

## Firestore patterns

### Flutter
```dart
// Generic repository pattern
class FirestoreRepository<T> {
  final CollectionReference _col;
  final T Function(Map<String, dynamic>) _fromMap;

  FirestoreRepository(String collection, this._fromMap)
      : _col = FirebaseFirestore.instance.collection(collection);

  Future<void> set(String id, Map<String, dynamic> data) =>
      _col.doc(id).set(data, SetOptions(merge: true));

  Stream<List<T>> watchAll() => _col.snapshots().map(
    (snap) => snap.docs.map((d) => _fromMap(d.data() as Map<String, dynamic>)).toList(),
  );
}
```

### Kotlin
```kotlin
suspend fun <T> DocumentReference.getAs(fromMap: (Map<String, Any>) -> T): T? =
    get().await().data?.let(fromMap)

fun <T> CollectionReference.watchAll(fromMap: (Map<String, Any>) -> T): Flow<List<T>> =
    callbackFlow {
        val listener = addSnapshotListener { snap, _ ->
            snap?.let { trySend(it.documents.mapNotNull { d -> d.data?.let(fromMap) }) }
        }
        awaitClose { listener.remove() }
    }
```

## Security rules (Firestore)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User can only access their own document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // Public read, authenticated write
    match /articles/{articleId} {
      allow read;
      allow write: if request.auth != null;
    }
  }
}
```

## FCM Push Notifications

### Flutter
```dart
// Request permission + get token
Future<void> setupPush() async {
  await FirebaseMessaging.instance.requestPermission();
  final token = await FirebaseMessaging.instance.getToken();
  // Save token to backend/Firestore
  
  // Foreground message handler
  FirebaseMessaging.onMessage.listen((message) {
    // Show local notification or update UI
  });
  
  // Background tap handler
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    // Navigate based on message.data
  });
}
```

## Common issues
- **iOS**: requires APNs certificate/key in Firebase console + `firebase_options.dart` must include correct `iosBundleId`
- **Android**: `google-services.json` must be in `app/` directory, not project root
- **Token expiry**: always handle `FirebaseAuthException` with code `token-expired` and refresh silently
- **Firestore offline**: enable offline persistence — Flutter: `settings = Settings(persistenceEnabled: true)`
