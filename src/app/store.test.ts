import { useNavigatorStore } from './store';

describe('navigator store', () => {
  beforeEach(() => {
    useNavigatorStore.getState().reset();
  });

  it('selects a destination and resets its route to the recommended path', () => {
    useNavigatorStore.getState().selectDestination('proxima');

    expect(useNavigatorStore.getState().selectedDestinationId).toBe('proxima');
    expect(useNavigatorStore.getState().selectedRouteId).toBe('proxima-recommended');
  });

  it('keeps overlay state and navigation state mutually clear', () => {
    useNavigatorStore.getState().openOverlay('destinations');
    expect(useNavigatorStore.getState().activeOverlay).toBe('destinations');

    useNavigatorStore.getState().startNavigation();
    expect(useNavigatorStore.getState().isNavigating).toBe(true);
    expect(useNavigatorStore.getState().activeOverlay).toBeNull();

    useNavigatorStore.getState().stopNavigation();
    expect(useNavigatorStore.getState().isNavigating).toBe(false);
  });

  it('updates the selected route without changing the destination', () => {
    useNavigatorStore.getState().selectRoute('andromeda-safest');

    expect(useNavigatorStore.getState().selectedDestinationId).toBe('andromeda');
    expect(useNavigatorStore.getState().selectedRouteId).toBe('andromeda-safest');
  });

  it('toggles map layers and restores them on reset', () => {
    useNavigatorStore.getState().toggleLayer('hazards');
    expect(useNavigatorStore.getState().visibleLayers.hazards).toBe(false);

    useNavigatorStore.getState().reset();
    expect(useNavigatorStore.getState().visibleLayers.hazards).toBe(true);
  });
});
