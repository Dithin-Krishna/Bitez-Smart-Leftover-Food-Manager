import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Handles saving and deleting expiry vault photos in local app storage.
/// Photos are stored in: `appDocumentsDir/expiry_vault/`
/// MongoDB only stores the file path, not the image bytes.
class LocalPhotoStorage {
  LocalPhotoStorage._();
  static final LocalPhotoStorage instance = LocalPhotoStorage._();

  /// Returns the expiry vault directory, creating it if needed.
  Future<Directory> get _vaultDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'expiry_vault'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Saves [sourceFile] to the vault with a unique timestamped name.
  /// Returns the absolute local path of the saved file.
  Future<String> saveExpiryPhoto(File sourceFile, {String? itemId}) async {
    final dir = await _vaultDir;
    final ext = p.extension(sourceFile.path).isNotEmpty
        ? p.extension(sourceFile.path)
        : '.jpg';
    final name = 'expiry_${itemId ?? 'item'}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(dir.path, name));
    await sourceFile.copy(dest.path);
    return dest.path;
  }

  /// Deletes the photo at [localPath] if it exists.
  Future<void> deletePhoto(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return;
    final f = File(localPath);
    if (await f.exists()) await f.delete();
  }

  /// Returns true if [value] looks like a local file path
  /// (not a Base64 blob or http URL).
  static bool isLocalPath(String? value) {
    if (value == null || value.isEmpty) return false;
    return !value.startsWith('data:') && !value.startsWith('http');
  }

  /// Returns true if [value] is a legacy Base64 blob still in the DB.
  static bool isBase64(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith('data:image');
  }
}
