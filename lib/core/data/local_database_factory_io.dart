import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

Future<Database> openWorkLogDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final factory = getDatabaseFactorySqflite(sqflite.databaseFactory);
  return factory.openDatabase(path.join(directory.path, 'worklog_offline.db'));
}
