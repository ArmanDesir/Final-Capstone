import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/content.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

class ContentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseStorageClient _storage = Supabase.instance.client.storage;
  final Uuid _uuid = Uuid();
  final Logger _logger = Logger();

  /// Prompts the user to pick a PDF file.
  Future<FilePickerResult?> pickPDFFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      return result;
    } catch (e) {
      _logger.e('Failed to pick file: $e');
      throw Exception('Failed to pick file: $e');
    }
  }

  /// Uploads a PDF file to Supabase Storage.
  Future<String> uploadPDFFile(
      File file,
      String classroomId,
      ) async {
    try {
      final fileName = '${_uuid.v4()}.pdf';
      final storagePath = 'classrooms/$classroomId/content/$fileName';

      _logger.i('Uploading file: $storagePath');

      // Upload the file to the 'content-files' bucket
      await _storage.from('content-files').uploadBinary(
        storagePath,
        file.readAsBytesSync(),
        fileOptions: const FileOptions(cacheControl: '3600'),
      );

      // Get the public URL for the uploaded file
      final fileUrl = _storage.from('content-files').getPublicUrl(storagePath);
      return fileUrl;
    } on StorageException catch (e) {
      _logger.e('Failed to upload file to storage: ${e.message}');
      throw Exception('Failed to upload file to storage: ${e.message}');
    } catch (e) {
      _logger.e('Failed to upload file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Creates a new content entry in the database and uploads the PDF.
  Future<Content> createContent({
    required String classroomId,
    required String title,
    required String description,
    required ContentType type,
    required File pdfFile,
  }) async {
    try {
      final fileUrl = await uploadPDFFile(pdfFile, classroomId);
      final fileName = fileUrl.split('/').last;

      final content = Content(
        id: _uuid.v4(),
        classroomId: classroomId,
        title: title,
        description: description,
        type: type,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: await pdfFile.length(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabase.from('content').insert(content.toJson());
      return content;
    } catch (e) {
      _logger.e('Failed to create content: $e');
      throw Exception('Failed to create content: $e');
    }
  }

  /// Retrieves a list of content items for a specific classroom.
  Future<List<Content>> getContentByClassroom(String classroomId) async {
    try {
      _logger.i('Loading content for classroom: $classroomId');
      final response = await _supabase
          .from('content')
          .select()
          .eq('classroom_id', classroomId)
          .order('created_at', ascending: false);

      _logger.i('Found ${response.length} content items');
      final contents = response.map((data) => Content.fromJson(data)).toList();
      return contents;
    } catch (e) {
      _logger.e('Error loading content: $e');
      throw Exception('Failed to get content: $e');
    }
  }

  /// Deletes a content entry from the database and the associated file from storage.
  Future<void> deleteContent(String contentId) async {
    try {
      // Fetch file_name and classroom_id first
      final response = await _supabase
          .from('content')
          .select('file_name, classroom_id')
          .eq('id', contentId)
          .single();

      final fileName = response['file_name'] as String;
      final classroomId = response['classroom_id'] as String;

      final storagePath = 'classrooms/$classroomId/content/$fileName';

      // Delete file from Supabase Storage
      await _storage.from('content-files').remove([storagePath]);

      // Delete entry from Supabase database
      await _supabase.from('content').delete().eq('id', contentId);

      _logger.i('Content with ID $contentId deleted successfully.');
    } on StorageException catch (e) {
      _logger.e('Failed to delete file from storage: ${e.message}');
      // Proceed with deleting the database entry even if file removal fails
      await _supabase.from('content').delete().eq('id', contentId);
      throw Exception('Failed to delete content file: ${e.message}');
    } catch (e) {
      _logger.e('Failed to delete content: $e');
      throw Exception('Failed to delete content: $e');
    }
  }
}
