# React Native Reference

## Project Structure

```
src/
├── app/
│   ├── App.tsx                # Root component
│   └── navigation/
│       ├── RootNavigator.tsx
│       └── AuthNavigator.tsx
├── core/
│   ├── api/                   # Axios instance, interceptors
│   ├── storage/               # AsyncStorage / SecureStore wrappers
│   └── hooks/                 # Shared custom hooks
├── features/
│   └── auth/
│       ├── api.ts             # Feature-specific API calls
│       ├── hooks.ts           # useAuth, useLogin
│       ├── store.ts           # Zustand slice or Redux slice
│       ├── types.ts
│       └── screens/
│           └── LoginScreen.tsx
└── shared/
    ├── components/            # Reusable components
    └── theme/                 # colors, spacing, typography
```

## State Management (Zustand — recommended)
```typescript
import { create } from 'zustand';

interface AuthState {
  user: User | null;
  token: string | null;
  status: 'idle' | 'loading' | 'error';
  error: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: null,
  status: 'idle',
  error: null,
  login: async (email, password) => {
    set({ status: 'loading', error: null });
    try {
      const { user, token } = await authApi.login(email, password);
      await SecureStore.setItemAsync('token', token);
      set({ user, token, status: 'idle' });
    } catch (e: any) {
      set({ status: 'error', error: e.message });
    }
  },
  logout: () => {
    SecureStore.deleteItemAsync('token');
    set({ user: null, token: null });
  },
}));
```

## Axios setup with interceptors
```typescript
import axios from 'axios';
import * as SecureStore from 'expo-secure-store';

export const api = axios.create({
  baseURL: process.env.EXPO_PUBLIC_API_URL,
  timeout: 15000,
});

api.interceptors.request.use(async (config) => {
  const token = await SecureStore.getItemAsync('token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) {
      // trigger logout
    }
    return Promise.reject(error);
  }
);
```

## Navigation (React Navigation v6)
```typescript
// RootNavigator.tsx
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

export type RootStackParamList = {
  Login: undefined;
  Home: undefined;
  Article: { id: string };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export const RootNavigator = () => {
  const { user } = useAuthStore();
  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {user ? (
          <>
            <Stack.Screen name="Home" component={HomeScreen} />
            <Stack.Screen name="Article" component={ArticleScreen} />
          </>
        ) : (
          <Stack.Screen name="Login" component={LoginScreen} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
};
```

## Performance patterns
```typescript
// Avoid re-renders with useCallback/memo
const renderItem = useCallback(({ item }: { item: Article }) => (
  <ArticleCard article={item} />
), []);

// FlashList over FlatList for long lists
import { FlashList } from '@shopify/flash-list';
<FlashList
  data={articles}
  renderItem={renderItem}
  estimatedItemSize={120}
  keyExtractor={(item) => item.id}
/>
```

## Key packages (package.json)
```json
{
  "dependencies": {
    "expo": "~51.0.0",
    "@react-navigation/native": "^6.1.17",
    "@react-navigation/native-stack": "^6.9.26",
    "axios": "^1.6.8",
    "zustand": "^4.5.2",
    "expo-secure-store": "~13.0.0",
    "@shopify/flash-list": "^1.6.4",
    "react-native-safe-area-context": "^4.10.1"
  }
}
```

## Expo Router (file-based navigation — preferred for new Expo projects)
```
app/
├── _layout.tsx        # Root layout — wrap with providers here
├── (auth)/
│   ├── _layout.tsx    # Stack for auth screens
│   ├── login.tsx
│   └── register.tsx
├── (tabs)/
│   ├── _layout.tsx    # Tab bar layout
│   ├── index.tsx      # /  (home tab)
│   └── profile.tsx    # /profile
└── article/
    └── [id].tsx       # /article/123 — dynamic segment
```

```typescript
// app/_layout.tsx — root layout
import { Stack } from 'expo-router';
import { useAuthStore } from '@/features/auth/store';

export default function RootLayout() {
  const user = useAuthStore((s) => s.user);
  return (
    <Stack screenOptions={{ headerShown: false }}>
      {user ? (
        <Stack.Screen name="(tabs)" />
      ) : (
        <Stack.Screen name="(auth)" />
      )}
    </Stack>
  );
}

// Navigate programmatically
import { router } from 'expo-router';
router.push('/article/123');
router.replace('/(auth)/login');

// Typed params with Zod or inline
import { useLocalSearchParams } from 'expo-router';
const { id } = useLocalSearchParams<{ id: string }>();
```

## NativeWind (Tailwind CSS for React Native)
```typescript
// tailwind.config.js — point at your source files
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{ts,tsx}', './src/**/*.{ts,tsx}'],
  presets: [require('nativewind/preset')],
};

// babel.config.js — add the preset
module.exports = { presets: ['babel-preset-expo', 'nativewind/babel'] };

// Usage: className prop works on all core RN components
export function ArticleCard({ title, author }: Props) {
  return (
    <View className="bg-white rounded-2xl p-4 shadow-sm mb-3">
      <Text className="text-lg font-semibold text-gray-900">{title}</Text>
      <Text className="text-sm text-gray-500 mt-1">{author}</Text>
    </View>
  );
}

// Dark mode: use dark: prefix + colorScheme from NativeWind
<View className="bg-white dark:bg-gray-900 flex-1" />
```

## Common pitfalls
- **Bridge bottleneck**: don't pass large objects or call JS ↔ Native too frequently in animations
- **Missing keyExtractor**: always provide stable, unique keys to FlatList/FlashList
- **Metro cache**: if weird bugs appear after package installs, run `npx expo start --clear`
- **Expo Go vs bare workflow**: some native modules require bare workflow (eject or use Expo's Dev Client)
- **useEffect cleanup**: cancel async operations on unmount to avoid state-update-on-unmounted errors
- **Expo Router vs React Navigation**: don't mix both — pick one per project
- **NativeWind v4**: requires `cssInterop` for third-party components; use `remapProps` from `nativewind` to add className support
