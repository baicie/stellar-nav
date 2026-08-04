const { defineConfig } = require('eslint/config');
const expoConfig = require('eslint-config-expo/flat');
const prettierRecommended = require('eslint-plugin-prettier/recommended');

module.exports = defineConfig([
  {
    ignores: ['.expo/**', 'coverage/**', 'dist/**', 'node_modules/**'],
  },
  ...expoConfig,
  {
    files: ['src/core/**/*.{ts,tsx}'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: [
                'expo',
                'expo-*',
                'react',
                'react-*',
                '@shopify/react-native-skia',
                'zustand',
              ],
              message: 'The domain core must remain independent from UI and platform frameworks.',
            },
          ],
        },
      ],
    },
  },
  prettierRecommended,
]);
