import 'package:flutter/material.dart';

class FileCategory {
  const FileCategory({
    required this.label, 
    required this.icon, 
    this.isImage = false,
    this.isAudio = false,
  });

  final String label;
  final IconData icon;
  final bool isImage;
  final bool isAudio;
}

final Set<String> _pdfExt = {'pdf'};
final Set<String> _archiveExt = {'zip', 'rar', '7z', 'tar', 'gz', 'bz2'};
final Set<String> _documentExt = {'pdf', 'doc', 'docx', 'odt', 'rtf'};
final Set<String> _spreadsheetExt = {'xls', 'xlsx', 'csv'};
final Set<String> _presentationExt = {'ppt', 'pptx', 'key'};
final Set<String> _textExt = {'txt', 'log', 'md'};
final Set<String> _audioExt = {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'};
final Set<String> _videoExt = {'mp4', 'avi', 'mkv', 'mov', 'webm', 'flv'};
final Set<String> _codeExt = {
  'dart', 'js', 'ts', 'java', 'py', 'c', 'cpp', 'cxx', 'h', 'hpp', 'cs', 'go', 'swift', 'kt', 'html', 'css', 'json', 'yaml', 'yml'
};
final Set<String> _imageExt = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'};

const _defaultCategory = FileCategory(label: '文件', icon: Icons.insert_drive_file);

FileCategory resolveFileCategory(String extension) {
  final ext = extension.toLowerCase();
  if (_archiveExt.contains(ext)) {
    return const FileCategory(label: '压缩包', icon: Icons.folder_zip);
  }
  if (_pdfExt.contains(ext)) {
    return const FileCategory(label: 'PDF', icon: Icons.picture_as_pdf);
  }
  if (_documentExt.contains(ext)) {
    return const FileCategory(label: '文档', icon: Icons.description);
  }
  if (_imageExt.contains(ext)) {
    return const FileCategory(label: '图片', icon: Icons.image, isImage: true);
  }
  if (_spreadsheetExt.contains(ext)) {
    return const FileCategory(label: '表格', icon: Icons.table_chart);
  }
  if (_presentationExt.contains(ext)) {
    return const FileCategory(label: '演示', icon: Icons.slideshow);
  }
  if (_textExt.contains(ext)) {
    return const FileCategory(label: '文本', icon: Icons.notes);
  }
  if (_audioExt.contains(ext)) {
    return const FileCategory(label: '音频', icon: Icons.audiotrack, isAudio: true);
  }
  if (_videoExt.contains(ext)) {
    return const FileCategory(label: '视频', icon: Icons.movie);
  }
  if (_codeExt.contains(ext)) {
    return const FileCategory(label: '代码', icon: Icons.code);
  }
  return _defaultCategory;
}

