interface BootstrapOptions<TComponent> {
  isWeb: boolean;
  loadRenderer: () => Promise<void>;
  loadApp: () => Promise<TComponent>;
  register: (component: TComponent) => void;
  fallbackComponent: TComponent;
  onError?: (error: unknown) => void;
}

export async function bootstrapApp<TComponent>({
  isWeb,
  loadRenderer,
  loadApp,
  register,
  fallbackComponent,
  onError,
}: BootstrapOptions<TComponent>): Promise<void> {
  try {
    if (isWeb) {
      await loadRenderer();
    }

    register(await loadApp());
  } catch (error) {
    onError?.(error);
    register(fallbackComponent);
  }
}
