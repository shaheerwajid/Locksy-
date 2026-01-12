import 'package:flutter/material.dart';
import 'package:CryptoChat/helpers/style.dart';

class VideoProcessingStatus extends StatelessWidget {
  final String? status; // 'uploading', 'processing', 'completed', 'failed'
  final double? progress; // 0.0 to 1.0
  final String? thumbnailUrl;
  final List<String>? availableResolutions;

  const VideoProcessingStatus({
    Key? key,
    this.status,
    this.progress,
    this.thumbnailUrl,
    this.availableResolutions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (status == 'completed' && thumbnailUrl != null) {
      return _buildCompletedState();
    } else if (status == 'processing' || status == 'uploading') {
      return _buildProcessingState();
    } else if (status == 'failed') {
      return _buildFailedState();
    }

    return const SizedBox.shrink();
  }

  Widget _buildCompletedState() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: thumbnailUrl != null
            ? DecorationImage(
                image: NetworkImage(thumbnailUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Stack(
        children: [
          if (availableResolutions != null && availableResolutions!.isNotEmpty)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${availableResolutions!.length} resolutions',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProcessingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gris.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
          ),
          const SizedBox(height: 8),
          Text(
            status == 'uploading' ? 'Uploading...' : 'Processing video...',
            style: TextStyle(fontSize: 12, color: gris),
          ),
          if (progress != null)
            Text(
              '${(progress! * 100).toInt()}%',
              style: TextStyle(fontSize: 10, color: gris),
            ),
        ],
      ),
    );
  }

  Widget _buildFailedState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Video processing failed',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}





