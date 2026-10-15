import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final commercialFormProvider =
    StateNotifierProvider<CommercialFormNotifier, Map<String, dynamic>>(
      (ref) => CommercialFormNotifier(),
    );

class CommercialFormNotifier extends StateNotifier<Map<String, dynamic>> {
  CommercialFormNotifier() : super({});

  void update(Map<String, dynamic> data) {
    state = {...state, ...data};
  }

  void clear() {
    state = {};
  }

  void updateData(Map<String, Object> map) {
    state = {...state, ...map};
  }
}
