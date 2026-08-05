import { render } from '@testing-library/react-native';

import App from './App';

const mockUseFonts = jest.fn();

jest.mock('@expo-google-fonts/oxanium', () => ({
  Oxanium_500Medium: 500,
  Oxanium_700Bold: 700,
  useFonts: (...args: unknown[]) => mockUseFonts(...args),
}));

jest.mock('react-native-safe-area-context', () => {
  const React = require('react') as typeof import('react');

  return {
    SafeAreaProvider: ({ children }: { children: React.ReactNode }) =>
      React.createElement(React.Fragment, null, children),
  };
});

jest.mock('./src/app/NavigatorScreen', () => {
  const React = require('react') as typeof import('react');
  const { View } = require('react-native') as typeof import('react-native');

  return {
    NavigatorScreen: () => React.createElement(View, { accessibilityLabel: '星际导航主界面' }),
  };
});

describe('App font loading', () => {
  it('renders the navigator with system fonts when custom fonts fail', async () => {
    mockUseFonts.mockReturnValue([false, new Error('font unavailable')]);

    const screen = await render(<App />);

    expect(screen.getByLabelText('星际导航主界面')).toBeTruthy();
  });
});
