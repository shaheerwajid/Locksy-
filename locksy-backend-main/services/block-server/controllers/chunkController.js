/*
 * Chunk Controller for Block Server
 * Handles chunked file uploads
 */

const { response } = require('express');
const blockServer = require('../../storage/blockServer');
const crypto = require('crypto');

/**
 * Initialize chunked upload
 */
const initializeChunkedUpload = async (req, res = response) => {
  try {
    const { fileName, fileSize, mimeType } = req.body;

    if (!fileName || !fileSize) {
      return res.status(400).json({
        ok: false,
        msg: 'fileName and fileSize are required'
      });
    }

    const result = blockServer.initializeChunkedUpload(
      fileName,
      parseInt(fileSize),
      mimeType || 'application/octet-stream'
    );

    res.json({
      ok: true,
      ...result
    });
  } catch (error) {
    console.error('Error initializing chunked upload:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al inicializar carga por chunks'
    });
  }
};

/**
 * Upload a chunk
 */
const uploadChunk = async (req, res = response) => {
  try {
    const { uploadId, chunkIndex, chunkHash } = req.body;

    if (!uploadId || chunkIndex === undefined || !chunkHash) {
      return res.status(400).json({
        ok: false,
        msg: 'uploadId, chunkIndex, and chunkHash are required'
      });
    }

    if (!req.file) {
      return res.status(400).json({
        ok: false,
        msg: 'Chunk data is required'
      });
    }

    // Read chunk data
    const fs = require('fs').promises;
    const chunkData = await fs.readFile(req.file.path);

    // Upload chunk
    const result = await blockServer.uploadChunk(
      uploadId,
      parseInt(chunkIndex),
      chunkData,
      chunkHash
    );

    // Clean up temp file
    try {
      await fs.unlink(req.file.path);
    } catch (err) {
      console.warn('Could not delete temp chunk file:', err.message);
    }

    res.json({
      ok: true,
      ...result
    });
  } catch (error) {
    console.error('Error uploading chunk:', error);
    res.status(500).json({
      ok: false,
      msg: error.message || 'Error al subir chunk'
    });
  }
};

/**
 * Complete chunked upload
 */
const completeChunkUpload = async (req, res = response) => {
  try {
    const { uploadId, folder } = req.body;

    if (!uploadId) {
      return res.status(400).json({
        ok: false,
        msg: 'uploadId is required'
      });
    }

    const result = await blockServer.completeChunkedUpload(
      uploadId,
      folder || 'general'
    );

    res.json({
      ok: true,
      file: result
    });
  } catch (error) {
    console.error('Error completing chunked upload:', error);
    res.status(500).json({
      ok: false,
      msg: error.message || 'Error al completar carga por chunks'
    });
  }
};

/**
 * Get upload progress
 */
const getUploadProgress = async (req, res = response) => {
  try {
    const { uploadId } = req.params;

    if (!uploadId) {
      return res.status(400).json({
        ok: false,
        msg: 'uploadId is required'
      });
    }

    const progress = blockServer.getUploadProgress(uploadId);

    if (!progress) {
      return res.status(404).json({
        ok: false,
        msg: 'Upload session not found'
      });
    }

    res.json({
      ok: true,
      progress
    });
  } catch (error) {
    console.error('Error getting upload progress:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener progreso de carga'
    });
  }
};

/**
 * Cancel chunked upload
 */
const cancelChunkUpload = async (req, res = response) => {
  try {
    const { uploadId } = req.body;

    if (!uploadId) {
      return res.status(400).json({
        ok: false,
        msg: 'uploadId is required'
      });
    }

    await blockServer.cancelChunkedUpload(uploadId);

    res.json({
      ok: true,
      msg: 'Upload cancelado'
    });
  } catch (error) {
    console.error('Error canceling chunked upload:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al cancelar carga'
    });
  }
};

module.exports = {
  initializeChunkedUpload,
  uploadChunk,
  completeChunkUpload,
  getUploadProgress,
  cancelChunkUpload
};


