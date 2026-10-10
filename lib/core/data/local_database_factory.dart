import 'package:sembast/sembast.dart';

import 'local_database_factory_io.dart' as platform;

Future<Database> openWorkLogLocalDatabase() => platform.openWorkLogDatabase();
