import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

/// JWT Bearer token gerektiren dekont ve sözleşme görsellerini ApiClient üzerinden
/// güvenli biçimde indirip Image.memory ile gösteren widget.
class AuthenticatedImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AuthenticatedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  static final Map<String, Uint8List> _cache = {};
  Uint8List? _bytes;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Görsel adresi boş';
        _bytes = null;
      });
      return;
    }

    if (_cache.containsKey(url)) {
      setState(() {
        _bytes = _cache[url];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = ApiClient.instance.resolveUri(url);
      final bytes = await ApiClient.instance.downloadFile(uri);
      _cache[url] = bytes;
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    }

    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      );
    }

    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey.shade200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, color: Colors.grey.shade500, size: 36),
              const SizedBox(height: 6),
              Text(
                _errorMessage ?? 'Görsel yüklenemedi',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
  }
}
