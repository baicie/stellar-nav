import { fireEvent, render } from '@testing-library/react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { NavigatorScreen } from './NavigatorScreen';
import { useNavigatorStore } from './store';

async function renderNavigator() {
  return render(
    <SafeAreaProvider
      initialMetrics={{
        frame: { x: 0, y: 0, width: 390, height: 844 },
        insets: { top: 0, right: 0, bottom: 0, left: 0 },
      }}
    >
      <NavigatorScreen />
    </SafeAreaProvider>,
  );
}

describe('NavigatorScreen', () => {
  beforeEach(() => {
    useNavigatorStore.getState().reset();
  });

  it('renders the star map controls and the recommended Andromeda route', async () => {
    const screen = await renderNavigator();

    expect(screen.getByLabelText('动态星图')).toBeTruthy();
    expect(screen.getAllByText('仙女座星系').length).toBeGreaterThan(0);
    expect(screen.getByText('262.44万光年')).toBeTruthy();
    expect(screen.getByText('模拟估算')).toBeTruthy();
    expect(screen.getByText('燃料')).toBeTruthy();
    expect(screen.getByText('风险')).toBeTruthy();
    expect(screen.getByText(/万单位$/)).toBeTruthy();
    expect(screen.getByText(/%$/)).toBeTruthy();
    expect(screen.getByLabelText('当前推荐航线，模拟估算，燃料99.7万单位，风险17%')).toBeTruthy();
    expect(screen.getByLabelText('航路方案列表').props.accessibilityRole).toBe('tablist');
    expect(screen.getByLabelText('开始导航')).toBeTruthy();
  });

  it('starts and stops navigation without changing the selected route', async () => {
    const screen = await renderNavigator();

    await fireEvent.press(screen.getByLabelText('开始导航'));
    expect(await screen.findByLabelText('结束航行')).toBeTruthy();
    expect(useNavigatorStore.getState().isNavigating).toBe(true);

    await fireEvent.press(screen.getByLabelText('结束航行'));
    expect(screen.getByLabelText('开始导航')).toBeTruthy();
    expect(useNavigatorStore.getState().selectedRouteId).toBe('andromeda-recommended');
  });

  it('opens destination search and switches to a nearby star', async () => {
    const screen = await renderNavigator();

    await fireEvent.press(screen.getByLabelText('选择目的地，当前为 仙女座星系'));
    expect((await screen.findByLabelText('目的地列表')).props.accessibilityRole).toBe('radiogroup');
    await fireEvent.press(await screen.findByLabelText('比邻星，Proxima Centauri · 红矮星'));

    expect(await screen.findByLabelText('选择目的地，当前为 比邻星')).toBeTruthy();
    expect(screen.getByText('4.25光年')).toBeTruthy();
    expect(useNavigatorStore.getState().selectedDestinationId).toBe('proxima');
  });

  it('switches to the lowest-risk route from the route rail', async () => {
    const screen = await renderNavigator();

    await fireEvent.press(screen.getByLabelText('避开黑洞航线，绕开已知的引力异常区'));

    expect(await screen.findByText('牺牲一点时间，换来不必和奇点讲道理。')).toBeTruthy();
    expect(
      screen.getByLabelText('当前避开黑洞航线，模拟估算，燃料163.5万单位，风险5%'),
    ).toBeTruthy();
    expect(useNavigatorStore.getState().selectedRouteId).toBe('andromeda-safest');
  });

  it('removes a disabled layer from the rendered map', async () => {
    const screen = await renderNavigator();

    await fireEvent.press(screen.getByLabelText('打开星图图层'));
    await fireEvent.press(await screen.findByLabelText('切换引力异常区'));
    await fireEvent.press(screen.getByRole('button', { name: '关闭星图图层' }));

    expect(screen.queryByText('引力异常区')).toBeNull();
  });

  it('marks the procedural star field as fictional instead of observed data', async () => {
    const screen = await renderNavigator();

    await fireEvent.press(screen.getByLabelText('打开星图图层'));

    expect(await screen.findByText('程序化背景与地图位置 · 设定；天体目录 · 推导')).toBeTruthy();
  });
});
