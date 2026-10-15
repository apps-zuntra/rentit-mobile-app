import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:rentit/providers/commercial_draft_provider.dart';

final commercialDraftProvider = ChangeNotifierProvider<CommercialDraftProvider>(
  (ref) => CommercialDraftProvider(),
);
