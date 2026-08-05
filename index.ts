import { registerRootComponent } from 'expo';
import { Platform } from 'react-native';

import { bootstrapApp } from './src/app/bootstrap';
import { StartupErrorScreen } from './src/app/StartupErrorScreen';

void bootstrapApp({
  isWeb: Platform.OS === 'web',
  loadRenderer: async () => {
    const { LoadSkiaWeb } = await import('@shopify/react-native-skia/lib/module/web');
    await LoadSkiaWeb();
  },
  loadApp: async () => (await import('./App')).default,
  register: registerRootComponent,
  fallbackComponent: StartupErrorScreen,
  onError: (error) => console.error('Application bootstrap failed', error),
});
