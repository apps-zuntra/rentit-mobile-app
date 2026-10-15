import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:rentit/model/model/flatmateDraftProvider.dart';


final flatmateDraftProvider = ChangeNotifierProvider<FlatmateDraftProvider>(
  (ref) => FlatmateDraftProvider(),
);
