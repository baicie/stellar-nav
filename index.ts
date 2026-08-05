import { registerRootComponent } from 'expo';
import { Platform } from 'react-native';

import { bootstrapApp } from './src/app/bootstrap';
import { loadRenderer } from './src/app/loadRenderer';
import { StartupErrorScreen } from './src/app/StartupErrorScreen';

void bootstrapApp({
  isWeb: Platform.OS === 'web',
  loadRenderer,
  loadApp: async () => (await import('./App')).default,
  register: registerRootComponent,
  fallbackComponent: StartupErrorScreen,
  onError: (error) => console.error('Application bootstrap failed', error),
});
