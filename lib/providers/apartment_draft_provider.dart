import 'package:flutter_riverpod/legacy.dart';
import 'package:rentit/model/model/apartment_draft_provider.dart';

final apartmentDraftProvider =
    ChangeNotifierProvider<ApartmentDraftProvider>(
  (ref) => ApartmentDraftProvider(),
);
