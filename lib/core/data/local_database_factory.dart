import 'package:sembast/sembast.dart';

import 'local_database_factory_stub.dart'
    if (dart.library.io) 'local_database_factory_io.dart'
    if (dart.library.js_interop) 'local_database_factory_web.dart' as platform;

Future<Database> openWorkLogLocalDatabase() => platform.openWorkLogDatabase();
