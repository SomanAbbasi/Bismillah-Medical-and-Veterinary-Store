import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class AttachmentResult {
  final String relativePath;
  final String originalName;
  final String mimeType;

  AttachmentResult({
    required this.relativePath,
    required this.originalName,
    required this.mimeType,
  });
}

class AttachmentService {
  final ImagePicker _imagePicker = ImagePicker();
  static const String attachmentsFolder = 'app_attachments';

  Future<Directory> getAttachmentsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, attachmentsFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> getAbsolutePath(String relativeOrFileName) async {
    final dir = await getAttachmentsDirectory();
    return p.join(dir.path, p.basename(relativeOrFileName));
  }

  Future<AttachmentResult?> capturePhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return null;
    return _saveFileToManagedDir(File(photo.path), photo.name, 'image/jpeg');
  }

  Future<AttachmentResult?> pickImageFromGallery() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (photo == null) return null;
    return _saveFileToManagedDir(File(photo.path), photo.name, 'image/jpeg');
  }

  Future<AttachmentResult?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final name = result.files.single.name;
    final ext = p.extension(name).toLowerCase();
    String mime = 'application/octet-stream';
    if (ext == '.pdf') mime = 'application/pdf';
    if (ext == '.jpg' || ext == '.jpeg') mime = 'image/jpeg';
    if (ext == '.png') mime = 'image/png';

    return _saveFileToManagedDir(file, name, mime);
  }

  Future<AttachmentResult> _saveFileToManagedDir(
    File sourceFile,
    String originalName,
    String mimeType,
  ) async {
    final dir = await getAttachmentsDirectory();
    final ext = p.extension(originalName).isNotEmpty
        ? p.extension(originalName)
        : '.jpg';
    final uniqueName = '${const Uuid().v4()}$ext';
    final destinationFile = File(p.join(dir.path, uniqueName));

    await sourceFile.copy(destinationFile.path);

    return AttachmentResult(
      relativePath: uniqueName,
      originalName: originalName,
      mimeType: mimeType,
    );
  }

  Future<void> shareAttachment(String relativeOrFileName, {String? text}) async {
    final fullPath = await getAbsolutePath(relativeOrFileName);
    final file = File(fullPath);
    if (await file.exists()) {
      await Share.shareXFiles([XFile(fullPath)], text: text);
    }
  }

  Future<bool> deleteAttachmentFile(String relativeOrFileName) async {
    final fullPath = await getAbsolutePath(relativeOrFileName);
    final file = File(fullPath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
}

final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService();
});
