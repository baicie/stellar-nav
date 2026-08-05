import { Crosshair } from 'lucide-react-native';
import { StatusBar } from 'expo-status-bar';
import { useCallback, useState } from 'react';
import { type LayoutChangeEvent, Share, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { estimateRoute } from '../core/navigation';
import { formatDuration } from '../core/formatters';
import { DESTINATIONS, DEFAULT_VESSEL, getDestination } from '../data/catalog';
import { colors, fontFamilies, radii, spacing } from '../design/tokens';
import { AiBrief } from '../components/AiBrief';
import { BottomControls } from '../components/BottomControls';
import { DestinationSheet } from '../components/DestinationSheet';
import { IconButton } from '../components/IconButton';
import { LayerSheet } from '../components/LayerSheet';
import { MapLabels } from '../components/MapLabels';
import { RouteRail } from '../components/RouteRail';
import { TopNav } from '../components/TopNav';
import { useNavigatorStore } from './store';
import { useReducedMotion } from './useReducedMotion';
import { StarMapCanvas } from '../renderer/StarMapCanvas';

const compactBottomOverlayHeight = 304;
const regularBottomOverlayHeight = 316;

export function NavigatorScreen() {
  const insets = useSafeAreaInsets();
  const reducedMotion = useReducedMotion();
  const [measuredBottomOcclusion, setMeasuredBottomOcclusion] = useState(0);
  const selectedDestinationId = useNavigatorStore((state) => state.selectedDestinationId);
  const selectedRouteId = useNavigatorStore((state) => state.selectedRouteId);
  const activeOverlay = useNavigatorStore((state) => state.activeOverlay);
  const isNavigating = useNavigatorStore((state) => state.isNavigating);
  const visibleLayers = useNavigatorStore((state) => state.visibleLayers);
  const selectDestination = useNavigatorStore((state) => state.selectDestination);
  const selectRoute = useNavigatorStore((state) => state.selectRoute);
  const openOverlay = useNavigatorStore((state) => state.openOverlay);
  const toggleLayer = useNavigatorStore((state) => state.toggleLayer);
  const startNavigation = useNavigatorStore((state) => state.startNavigation);
  const stopNavigation = useNavigatorStore((state) => state.stopNavigation);
  const destination = getDestination(selectedDestinationId);
  const route =
    destination.routes.find((item) => item.id === selectedRouteId) ?? destination.routes[0]!;
  const metrics = estimateRoute(route, DEFAULT_VESSEL.profile);
  const isCompact = insets.bottom > 0 ? false : true;
  const estimatedBottomOcclusion =
    (isCompact ? compactBottomOverlayHeight : regularBottomOverlayHeight) + insets.bottom;
  const bottomOcclusion = Math.max(measuredBottomOcclusion, estimatedBottomOcclusion);

  const handleBottomLayout = useCallback((event: LayoutChangeEvent) => {
    const nextHeight = Math.ceil(event.nativeEvent.layout.height);
    setMeasuredBottomOcclusion((currentHeight) =>
      currentHeight === nextHeight ? currentHeight : nextHeight,
    );
  }, []);

  const handleShare = () => {
    void Share.share({
      message: `我在缺德导航规划去${destination.name}的「${route.label}」航线：${formatDuration(metrics.estimatedYears)}。`,
      title: '分享星际航线',
    }).catch(() => undefined);
  };

  return (
    <View style={styles.screen}>
      <StatusBar style="light" />
      <StarMapCanvas
        destinationAnchor={destination.mapAnchor}
        isNavigating={isNavigating}
        reducedMotion={reducedMotion}
        routeId={route.id}
        routeVisual={route.visual}
        visibleLayers={visibleLayers}
      />
      <MapLabels
        bottomOcclusion={bottomOcclusion}
        destination={destination}
        visibleLayers={visibleLayers}
      />

      <View style={styles.overlay}>
        <View style={[styles.topArea, { paddingTop: insets.top + spacing.sm }]}>
          <TopNav
            destination={destination}
            onDestinationPress={() => openOverlay('destinations')}
            onLayersPress={() => openOverlay('layers')}
          />
        </View>

        <View style={[styles.mapControls, { top: insets.top + 172 }]}>
          <IconButton disabled icon={Crosshair} label="视图已聚焦到当前位置" active tone="cyan" />
        </View>

        {isNavigating && (
          <View style={[styles.navigationPill, { top: insets.top + 174 }]}>
            <View style={styles.liveDot} />
            <Text style={styles.navigationText}>
              航行中 · {formatDuration(metrics.estimatedYears)}
            </Text>
          </View>
        )}

        <View
          onLayout={handleBottomLayout}
          style={[styles.bottomArea, { paddingBottom: insets.bottom + spacing.sm }]}
        >
          <View style={styles.bottomContent}>
            <RouteRail
              compact={isCompact}
              destination={destination}
              onSelect={selectRoute}
              selectedRouteId={route.id}
            />
            <AiBrief isNavigating={isNavigating} route={route} />
            <BottomControls
              compact={isCompact}
              isNavigating={isNavigating}
              onMapPress={() => openOverlay('layers')}
              onShare={handleShare}
              onStartPress={isNavigating ? stopNavigation : startNavigation}
            />
          </View>
        </View>
      </View>

      <DestinationSheet
        destinations={DESTINATIONS}
        onClose={() => openOverlay(null)}
        onSelect={selectDestination}
        selectedDestinationId={destination.id}
        visible={activeOverlay === 'destinations'}
      />
      <LayerSheet
        enabledLayers={visibleLayers}
        onClose={() => openOverlay(null)}
        onToggle={toggleLayer}
        visible={activeOverlay === 'layers'}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    backgroundColor: colors.canvas,
    flex: 1,
  },
  overlay: {
    ...StyleSheet.absoluteFill,
    pointerEvents: 'box-none',
  },
  topArea: {
    alignSelf: 'center',
    maxWidth: 760,
    pointerEvents: 'box-none',
    width: '100%',
  },
  mapControls: {
    pointerEvents: 'box-none',
    position: 'absolute',
    right: spacing.lg,
  },
  navigationPill: {
    alignItems: 'center',
    backgroundColor: 'rgba(8, 18, 26, 0.86)',
    borderColor: 'rgba(143, 226, 181, 0.52)',
    borderRadius: radii.pill,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 6,
    paddingHorizontal: spacing.sm,
    paddingVertical: 5,
    position: 'absolute',
    right: spacing.lg,
  },
  liveDot: {
    backgroundColor: colors.green,
    borderRadius: radii.pill,
    height: 6,
    width: 6,
  },
  navigationText: {
    color: colors.green,
    fontFamily: fontFamilies.display,
    fontSize: 10,
    letterSpacing: 0.3,
  },
  bottomArea: {
    bottom: 0,
    left: 0,
    pointerEvents: 'box-none',
    position: 'absolute',
    right: 0,
  },
  bottomContent: {
    alignSelf: 'center',
    maxWidth: 760,
    width: '100%',
  },
});
