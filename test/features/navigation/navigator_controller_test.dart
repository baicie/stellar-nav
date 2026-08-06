import 'package:astro_nav/src/domain/models.dart';
import 'package:astro_nav/src/features/navigation/navigator_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../support/fake_navigation_repository.dart';

void main() {
  test('initializes the ISS to lunar base teaching route', () {
    final repository = FakeNavigationRepository();
    final container = ProviderContainer(
      overrides: [navigationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final state = container.read(navigatorProvider);

    expect(state.originId, 'sol/earth/iss');
    expect(state.destinationId, 'sol/earth/moon/artemis-base');
    expect(state.routes, hasLength(3));
    expect(
      state.routes.every(
        (route) => route.provenance.nature == DataNature.simulated,
      ),
      isTrue,
    );
  });

  test('search, destination and timeline changes refresh engine outputs', () {
    final repository = FakeNavigationRepository();
    final container = ProviderContainer(
      overrides: [navigationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(navigatorProvider.notifier);

    controller.search('火星');
    expect(
      container.read(navigatorProvider).searchResults.single.id,
      'sol/mars',
    );

    controller.setDestination('sol/mars');
    controller.setSimulationDay(9712.0);

    final state = container.read(navigatorProvider);
    expect(state.destinationId, 'sol/mars');
    expect(state.simulationDay, 9712.0);
    expect(repository.lastPositionDay, 9712.0);
    expect(repository.lastDestinationId, 'sol/mars');
  });

  test(
    'origin changes require a reachable object distinct from destination',
    () {
      final repository = FakeNavigationRepository();
      final container = ProviderContainer(
        overrides: [navigationRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(navigatorProvider.notifier);

      controller.setOrigin('sol/mars');
      expect(container.read(navigatorProvider).originId, 'sol/mars');

      controller.setOrigin('sol/sun');
      expect(container.read(navigatorProvider).originId, 'sol/mars');

      controller.setOrigin('sol/earth/moon/artemis-base');
      expect(container.read(navigatorProvider).originId, 'sol/mars');
    },
  );

  test('navigation start is committed state, not frame progress', () {
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(navigatorProvider.notifier);

    controller.startNavigation();
    expect(container.read(navigatorProvider).isNavigating, isTrue);

    controller.stopNavigation();
    expect(container.read(navigatorProvider).isNavigating, isFalse);
  });

  test('changing route strategy stops an active simulation', () {
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(navigatorProvider.notifier);

    controller.startNavigation();
    controller.chooseStrategy(RouteStrategy.fastest);

    expect(container.read(navigatorProvider).isNavigating, isFalse);
  });

  test('submitting a new simulation time stops an active simulation', () {
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(navigatorProvider.notifier);

    controller.startNavigation();
    controller.setSimulationDay(9712);

    expect(container.read(navigatorProvider).isNavigating, isFalse);
  });
}
