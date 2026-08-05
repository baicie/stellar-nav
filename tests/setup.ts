import { setUpTests } from 'react-native-reanimated';
import type { ReactNode } from 'react';

type MockViewProps = { children?: ReactNode; [key: string]: unknown };

jest.mock('@shopify/react-native-skia', () => {
  const React = require('react') as typeof import('react');
  const { View } = require('react-native') as typeof import('react-native');
  const passthrough = ({ children, ...props }: MockViewProps) =>
    React.createElement(View, props, children);

  return {
    Canvas: passthrough,
    Circle: passthrough,
    Path: passthrough,
    Skia: {
      PathBuilder: {
        Make: () => ({
          addCircle: () => undefined,
          cubicTo: () => undefined,
          detach: () => ({}),
          moveTo: () => undefined,
        }),
      },
    },
  };
});

jest.mock('expo-blur', () => {
  const React = require('react') as typeof import('react');
  const { View } = require('react-native') as typeof import('react-native');

  return {
    BlurView: ({ children, ...props }: { children?: React.ReactNode } & Record<string, unknown>) =>
      React.createElement(View, props, children),
  };
});

setUpTests();
