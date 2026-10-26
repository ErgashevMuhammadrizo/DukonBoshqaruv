import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerWidget extends StatefulWidget {
  final String? initialImagePath;
  final Function(String?) onImageSelected;

  const ImagePickerWidget({
    super.key,
    this.initialImagePath,
    required this.onImageSelected,
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.initialImagePath;
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isProcessing = true);

    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (!mounted) return;
        if (status.isDenied || status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kamera ruxsati berilmagan. Sozlamalardan ruxsatni yoqing.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      } else {
        final status = await Permission.photos.request();
        if (!mounted) return;
        if (status.isDenied || status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Galereya ruxsati berilmagan. Sozlamalardan ruxsatni yoqing.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final extension = image.name.split('.').last.toLowerCase();
        final size = await image.length();
        if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
          throw const FormatException('JPG, PNG yoki WebP rasm tanlang.');
        }
        if (size > 5 * 1024 * 1024) {
          throw const FormatException('Rasm hajmi 5 MB dan oshmasligi kerak.');
        }
        setState(() => _imagePath = image.path);
        widget.onImageSelected(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(e is FormatException
                        ? e.message
                        : 'Rasmni tanlab bo‘lmadi.')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final supportsCamera = kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Rasm yuklash',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (supportsCamera)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.photo_camera_rounded,
                          color: Colors.blue[700]),
                    ),
                    title: const Text('Kamera',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Yangi surat olish'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.photo_library_rounded,
                        color: Colors.green[700]),
                  ),
                  title: const Text('Galereyadan',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Mavjud rasmdan tanlash'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_imagePath != null)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.delete_rounded, color: Colors.red[700]),
                    ),
                    title: const Text(
                      'Rasmni o\'chirish',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text('Mahsulot rasmisiz bo\'ladi'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _imagePath = null;
                      });
                      widget.onImageSelected(null);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rasm o\'chirildi'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: _isProcessing ? null : _showImageSourceDialog,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: _imagePath == null
                ? LinearGradient(
                    colors: [Colors.grey[100]!, Colors.grey[50]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: _isProcessing
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Yuklanmoqda...'),
                    ],
                  ),
                )
              : _imagePath != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _imagePath!.startsWith('http')
                              ? Image.network(_imagePath!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image)))
                              : FutureBuilder<Uint8List>(
                                  future: XFile(_imagePath!).readAsBytes(),
                                  builder: (context, snapshot) => snapshot
                                          .hasData
                                      ? Image.memory(snapshot.data!,
                                          fit: BoxFit.cover)
                                      : const Center(
                                          child: CircularProgressIndicator()),
                                ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: _showImageSourceDialog,
                                  tooltip: 'Rasmni o\'zgartirish',
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.green, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Rasm yuklandi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 48,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Mahsulot rasmini yuklash',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Bosing',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
