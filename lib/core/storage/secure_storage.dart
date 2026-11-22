import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one secure storage of the app (session token, welcome progress,
/// reminders, favourites, local account data). Every caller uses this same
/// configuration so all keys share one cipher and one migration.
///
/// Upgrading from flutter_secure_storage 9.2.4 to 10.x: data written by 9.x
/// (RSA/ECB/PKCS1 + AES/CBC) is read with the old ciphers and re-encrypted
/// with the new defaults on first access (`migrateOnAlgorithmChange`, on by
/// default). `migrateWithBackup` keeps a copy until that finishes, so a crash
/// in the middle does not lose the session. Do not jump to 11.x until every
/// installation has run a 10.x build: 11.x no longer reads 9.x data.
const appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(migrateWithBackup: true),
);
