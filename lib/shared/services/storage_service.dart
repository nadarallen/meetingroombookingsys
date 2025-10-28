import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadRoomImage({
    required String roomId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final sanitizedName =
        fileName.isEmpty ? 'room_${DateTime.now().millisecondsSinceEpoch}' : fileName;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('rooms/$roomId/$timestamp-$sanitizedName');
    final metadata = SettableMetadata(contentType: _inferContentType(sanitizedName));
    final task = await ref.putData(bytes, metadata);
    await task.ref.updateMetadata(metadata);
    return task.ref.getDownloadURL();
  }

  String? _inferContentType(String fileName) {
    final extension = p.extension(fileName).toLowerCase();
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return null;
    }
  }
}
