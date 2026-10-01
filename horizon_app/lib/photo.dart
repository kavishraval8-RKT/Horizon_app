import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'theme.dart';

final _picker = ImagePicker();

/// Ask Camera or Gallery, then pick a photo already shrunk for upload
/// (about 1280px, JPEG quality 70: roughly 150 KB instead of several MB).
Future<XFile?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  try {
    final photo = await _picker.pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 70);
    if (photo == null || _supported(photo)) return photo;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please choose a JPEG, PNG or WebP photo.'), backgroundColor: C.danger),
      );
    }
    return null;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't open the ${source.name}."), backgroundColor: C.danger),
      );
    }
    return null;
  }
}

/// Same list the server accepts (backend migration 1790500000).
const _types = {'jpg', 'jpeg', 'png', 'webp'};

bool _supported(XFile photo) {
  final mime = photo.mimeType;
  if (mime != null && mime.startsWith('image/')) return _types.contains(mime.substring(6));
  final dot = photo.name.lastIndexOf('.');
  // No type info at all (some web pickers): let the server decide and explain
  return dot < 0 || _types.contains(photo.name.substring(dot + 1).toLowerCase());
}

/// The picked photo as an upload part for the ledger's `photo` field.
Future<http.MultipartFile> photoPart(XFile photo) async =>
    http.MultipartFile.fromBytes('photo', await photo.readAsBytes(), filename: photo.name);

/// "Add photo" button that turns into a small preview with a remove control once picked.
class PhotoField extends StatelessWidget {
  final XFile? photo;
  final ValueChanged<XFile?> onChanged;
  final String label;
  const PhotoField({super.key, required this.photo, required this.onChanged, this.label = 'Add photo (optional)'});

  @override
  Widget build(BuildContext context) {
    final p = photo;
    if (p == null) {
      return OutlinedButton.icon(
        onPressed: () async => onChanged(await pickPhoto(context)),
        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
        label: Text(label),
      );
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 56,
            height: 56,
            child: kIsWeb ? Image.network(p.path, fit: BoxFit.cover) : Image.file(File(p.path), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text('Photo attached', style: TextStyle(color: C.muted))),
        TextButton(onPressed: () => onChanged(null), child: const Text('Remove')),
      ],
    );
  }
}
