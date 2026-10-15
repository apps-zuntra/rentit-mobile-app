import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentit/feature/visit/VisitRepository.dart';

final visitRepoProvider =
    Provider((ref) => VisitRepository());

// ---------------------------------------------
// TENANT VISITS
// ---------------------------------------------

final visitProvider =
    AsyncNotifierProvider<VisitNotifier, List<dynamic>>(
  VisitNotifier.new,
);

class VisitNotifier
    extends AsyncNotifier<List<dynamic>> {

  VisitRepository get _repo =>
      ref.read(visitRepoProvider);

  @override
  Future<List<dynamic>> build() async {
    final data = await _repo.fetchVisits();

    print(
      "? MY VISITS COUNT => ${data.length}",
    );

    return data;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => _repo.fetchVisits(),
    );
  }

  Future<void> cancelVisit(int id) async {
    await _repo.cancelVisit(id);
    await refresh();
  }
}

// ---------------------------------------------
// OWNER VISITS
// ---------------------------------------------

final ownerVisitProvider =
    AsyncNotifierProvider<
        OwnerVisitNotifier,
        List<dynamic>>(
  OwnerVisitNotifier.new,
);

class OwnerVisitNotifier
    extends AsyncNotifier<List<dynamic>> {

  VisitRepository get _repo =>
      ref.read(visitRepoProvider);

  @override
  Future<List<dynamic>> build() async {
    final data =
        await _repo.fetchOwnerVisits();

    print(
      "?? OWNER VISITS COUNT => ${data.length}",
    );

    print(
      "?? OWNER VISITS DATA => $data",
    );

    return data;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => _repo.fetchOwnerVisits(),
    );
  }
}
