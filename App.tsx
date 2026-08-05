import { useFonts, Oxanium_500Medium, Oxanium_700Bold } from '@expo-google-fonts/oxanium';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StyleSheet, View } from 'react-native';

import { NavigatorScreen } from './src/app/NavigatorScreen';
import { colors } from './src/design/tokens';

export default function App() {
  const [fontsLoaded, fontError] = useFonts({ Oxanium_500Medium, Oxanium_700Bold });

  if (!fontsLoaded && !fontError) {
    return <View style={styles.loading} />;
  }

  return (
    <SafeAreaProvider>
      <NavigatorScreen />
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  loading: {
    backgroundColor: colors.canvas,
    flex: 1,
  },
});
