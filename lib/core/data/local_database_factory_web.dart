import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

Future<Database> openWorkLogDatabase() =>
    databaseFactoryWeb.openDatabase('worklog_offline.db');
