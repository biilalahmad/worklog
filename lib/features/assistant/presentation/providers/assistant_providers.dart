import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/assistant_service.dart';

final assistantServiceProvider =
    Provider<AssistantService>((ref) => AssistantService());
