import 'package:flutter_riverpod/legacy.dart';
import 'package:rentit/model/model/pg_draft_provider.dart';

final pgDraftProvider =
    ChangeNotifierProvider<PGDraftProvider>(
  (ref) => PGDraftProvider(),
);
