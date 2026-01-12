/*
 * Block Server Routes
 * File upload, download, and chunk management routes
 */

const express = require('express');
const router = express.Router();
const uploadController = require('./controllers/uploadController');
const downloadController = require('./controllers/downloadController');
const chunkController = require('./controllers/chunkController');

// JWT validation middleware
const { validarJWT } = require('../../middlewares/validar-jwt');

// File upload routes
const multer = require('multer');
const upload = multer({ dest: 'uploads/' });

router.post('/upload', validarJWT, upload.single('file'), uploadController.uploadFile);
router.post('/init-chunk-upload', validarJWT, chunkController.initializeChunkedUpload);
router.post('/upload-chunk', validarJWT, upload.single('chunk'), chunkController.uploadChunk);
router.post('/complete-chunk-upload', validarJWT, chunkController.completeChunkUpload);
router.get('/upload-progress/:uploadId', validarJWT, chunkController.getUploadProgress);
router.post('/cancel-chunk-upload', validarJWT, chunkController.cancelChunkUpload);

// File download routes
router.get('/download/:fileId', validarJWT, downloadController.downloadFile);
router.get('/download-chunk/:fileId/:chunkIndex', validarJWT, downloadController.downloadChunk);
router.get('/presigned-url/:fileId', validarJWT, downloadController.getPresignedUrl);

// File management routes
router.delete('/:fileId', validarJWT, uploadController.deleteFile);
router.get('/info/:fileId', validarJWT, uploadController.getFileInfo);

// Legacy routes (for backward compatibility)
router.post('/subirArchivos', validarJWT, uploadController.subirArchivos);
router.get('/getFile', downloadController.getFile);
router.get('/getavatars', validarJWT, uploadController.getavatars);
router.get('/getgruposimg', validarJWT, uploadController.getgruposimg);

module.exports = router;

