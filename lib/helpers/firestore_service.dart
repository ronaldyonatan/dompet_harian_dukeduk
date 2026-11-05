import 'database_helper.dart';
import 'local_sync.dart';

class FirestoreService {
  Future<void> uploadBudgetsToCloud() => LocalSync.sync();
  Future<void> uploadLocalDataToCloud() => LocalSync.sync();
  Future<void> initializeUserDataOnFirstLaunch() =>
      DatabaseHelper.instance.initDefaultData();
}
