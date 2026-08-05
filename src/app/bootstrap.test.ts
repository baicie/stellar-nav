import { bootstrapApp } from './bootstrap';

describe('bootstrapApp', () => {
  const AppComponent = () => null;
  const StartupErrorComponent = () => null;

  it('loads CanvasKit before registering the app on web', async () => {
    const events: string[] = [];

    await bootstrapApp({
      isWeb: true,
      loadRenderer: async () => {
        events.push('renderer');
      },
      loadApp: async () => {
        events.push('app');
        return AppComponent;
      },
      register: () => {
        events.push('register');
      },
      fallbackComponent: StartupErrorComponent,
    });

    expect(events).toEqual(['renderer', 'app', 'register']);
  });

  it('registers the fallback when CanvasKit fails', async () => {
    const register = jest.fn();
    const loadApp = jest.fn(async () => AppComponent);
    const loadError = new Error('CanvasKit unavailable');
    const onError = jest.fn();

    await bootstrapApp({
      isWeb: true,
      loadRenderer: async () => {
        throw loadError;
      },
      loadApp,
      register,
      fallbackComponent: StartupErrorComponent,
      onError,
    });

    expect(loadApp).not.toHaveBeenCalled();
    expect(register).toHaveBeenCalledWith(StartupErrorComponent);
    expect(onError).toHaveBeenCalledWith(loadError);
  });

  it('skips the web renderer loader on native platforms', async () => {
    const loadRenderer = jest.fn(async () => undefined);
    const register = jest.fn();

    await bootstrapApp({
      isWeb: false,
      loadRenderer,
      loadApp: async () => AppComponent,
      register,
      fallbackComponent: StartupErrorComponent,
    });

    expect(loadRenderer).not.toHaveBeenCalled();
    expect(register).toHaveBeenCalledWith(AppComponent);
  });
});
