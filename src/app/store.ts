import { create } from 'zustand';

import { DESTINATIONS, getDestination } from '../data/catalog';
import type { MapLayerId, MapLayerVisibility } from '../renderer/layers';

export type NavigatorOverlay = 'destinations' | 'layers' | null;

interface NavigatorState {
  selectedDestinationId: string;
  selectedRouteId: string;
  preference: 'balanced' | 'fastest' | 'safest';
  activeOverlay: NavigatorOverlay;
  isNavigating: boolean;
  visibleLayers: MapLayerVisibility;
  selectDestination: (destinationId: string) => void;
  selectRoute: (routeId: string) => void;
  setPreference: (preference: NavigatorState['preference']) => void;
  openOverlay: (overlay: NavigatorOverlay) => void;
  toggleLayer: (layerId: MapLayerId) => void;
  startNavigation: () => void;
  stopNavigation: () => void;
  reset: () => void;
}

const initialDestination = DESTINATIONS[0]!;
const initialState = {
  selectedDestinationId: initialDestination.id,
  selectedRouteId: initialDestination.routes[0]!.id,
  preference: 'balanced' as const,
  activeOverlay: null as NavigatorOverlay,
  isNavigating: false,
  visibleLayers: {
    stars: true,
    routes: true,
    hazards: true,
  },
};

export const useNavigatorStore = create<NavigatorState>((set) => ({
  ...initialState,
  selectDestination: (destinationId) => {
    const destination = getDestination(destinationId);
    set({
      selectedDestinationId: destination.id,
      selectedRouteId: destination.routes[0]!.id,
      activeOverlay: null,
      isNavigating: false,
    });
  },
  selectRoute: (routeId) => {
    const destination = DESTINATIONS.find((item) =>
      item.routes.some((route) => route.id === routeId),
    );
    if (!destination) {
      return;
    }

    set({ selectedDestinationId: destination.id, selectedRouteId: routeId });
  },
  setPreference: (preference) => set({ preference }),
  openOverlay: (activeOverlay) => set({ activeOverlay, isNavigating: false }),
  toggleLayer: (layerId) =>
    set((state) => ({
      visibleLayers: {
        ...state.visibleLayers,
        [layerId]: !state.visibleLayers[layerId],
      },
    })),
  startNavigation: () => set({ activeOverlay: null, isNavigating: true }),
  stopNavigation: () => set({ isNavigating: false }),
  reset: () => set(initialState),
}));
