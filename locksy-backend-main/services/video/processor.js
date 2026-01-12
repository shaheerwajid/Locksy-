/*
 * Video Processing Service
 * Handles video transcoding, thumbnail generation, and metadata extraction
 */

const ffmpeg = require('fluent-ffmpeg');
const ffmpegStatic = require('ffmpeg-static');
const path = require('path');
const fs = require('fs').promises;
const fileService = require('../storage/fileService');

// Set ffmpeg path
ffmpeg.setFfmpegPath(ffmpegStatic);

class VideoProcessor {
  /**
   * Process video: transcode and generate thumbnails
   */
  async processVideo(videoPath, videoId, options = {}) {
    try {
      const resolutions = options.resolutions || ['720p', '1080p'];
      const processedVideos = [];

      // Generate thumbnails
      const thumbnails = await this.generateThumbnails(videoPath, videoId);

      // Transcode to different resolutions
      for (const resolution of resolutions) {
        const processed = await this.transcodeVideo(videoPath, videoId, resolution);
        if (processed) {
          processedVideos.push(processed);
        }
      }

      // Extract metadata
      const metadata = await this.extractMetadata(videoPath);

      return {
        success: true,
        thumbnails,
        videos: processedVideos,
        metadata,
      };
    } catch (error) {
      console.error('VideoProcessor: Processing failed', error.message);
      throw error;
    }
  }

  /**
   * Transcode video to specific resolution
   */
  async transcodeVideo(inputPath, videoId, resolution) {
    return new Promise((resolve, reject) => {
      const outputPath = path.join(
        path.dirname(inputPath),
        `${videoId}-${resolution}.mp4`
      );

      const command = ffmpeg(inputPath);

      // Set resolution
      if (resolution === '720p') {
        command.videoCodec('libx264').size('1280x720');
      } else if (resolution === '1080p') {
        command.videoCodec('libx264').size('1920x1080');
      } else {
        command.videoCodec('libx264');
      }

      command
        .on('end', async () => {
          try {
            // Upload processed video to storage
            const file = {
              path: outputPath,
              originalname: `${videoId}-${resolution}.mp4`,
              mimetype: 'video/mp4',
              size: (await fs.stat(outputPath)).size,
            };

            const result = await fileService.uploadFile(file, 'videos/processed');
            await fs.unlink(outputPath); // Clean up local file

            resolve({
              resolution,
              url: result.url,
              path: result.path,
            });
          } catch (error) {
            reject(error);
          }
        })
        .on('error', (err) => {
          reject(err);
        })
        .save(outputPath);
    });
  }

  /**
   * Generate thumbnails
   */
  async generateThumbnails(videoPath, videoId, count = 3) {
    return new Promise((resolve, reject) => {
      const thumbnails = [];
      const outputDir = path.dirname(videoPath);

      ffmpeg(videoPath)
        .screenshots({
          count,
          folder: outputDir,
          filename: `${videoId}-thumbnail-%i.png`,
          size: '320x240',
        })
        .on('end', async () => {
          try {
            // Upload thumbnails
            for (let i = 0; i < count; i++) {
              const thumbPath = path.join(outputDir, `${videoId}-thumbnail-${i + 1}.png`);
              const file = {
                path: thumbPath,
                originalname: `${videoId}-thumbnail-${i + 1}.png`,
                mimetype: 'image/png',
                size: (await fs.stat(thumbPath)).size,
              };

              const result = await fileService.uploadFile(file, 'thumbnails');
              thumbnails.push(result.url);
              await fs.unlink(thumbPath); // Clean up
            }

            resolve(thumbnails);
          } catch (error) {
            reject(error);
          }
        })
        .on('error', (err) => {
          reject(err);
        });
    });
  }

  /**
   * Extract video metadata
   */
  async extractMetadata(videoPath) {
    return new Promise((resolve, reject) => {
      ffmpeg.ffprobe(videoPath, (err, metadata) => {
        if (err) {
          reject(err);
          return;
        }

        resolve({
          duration: metadata.format.duration,
          size: metadata.format.size,
          bitrate: metadata.format.bit_rate,
          video: metadata.streams.find(s => s.codec_type === 'video'),
          audio: metadata.streams.find(s => s.codec_type === 'audio'),
        });
      });
    });
  }
}

// Export singleton instance
const videoProcessor = new VideoProcessor();
module.exports = videoProcessor;

