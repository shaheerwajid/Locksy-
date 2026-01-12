/*
 * Centralized Logger Service
 * Uses Winston for structured logging with multiple transports
 */

const winston = require('winston');
const path = require('path');
const config = require('../../config');

// Define log format
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  winston.format.json()
);

// Console format for development
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.printf(({ timestamp, level, message, ...metadata }) => {
    let msg = `${timestamp} [${level}]: ${message}`;
    if (Object.keys(metadata).length > 0) {
      msg += ` ${JSON.stringify(metadata)}`;
    }
    return msg;
  })
);

// Create transports
const transports = [];

// Console transport (always enabled)
transports.push(
  new winston.transports.Console({
    format: config.server.nodeEnv === 'production' ? logFormat : consoleFormat,
    level: config.logging.level || 'info',
  })
);

// File transport for errors
if (config.server.nodeEnv === 'production') {
  const logsDir = path.dirname(config.logging.file || 'logs/app.log');
  
  transports.push(
    new winston.transports.File({
      filename: path.join(logsDir, 'error.log'),
      level: 'error',
      format: logFormat,
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    })
  );

  // File transport for all logs
  transports.push(
    new winston.transports.File({
      filename: config.logging.file || 'logs/app.log',
      format: logFormat,
      maxsize: 5242880, // 5MB
      maxFiles: 10,
    })
  );
}

// Create logger instance
const logger = winston.createLogger({
  level: config.logging.level || 'info',
  format: logFormat,
  defaultMeta: { service: 'locksy-backend' },
  transports,
  // Handle exceptions
  exceptionHandlers: [
    new winston.transports.File({ filename: 'logs/exceptions.log' }),
  ],
  // Handle rejections
  rejectionHandlers: [
    new winston.transports.File({ filename: 'logs/rejections.log' }),
  ],
});

/**
 * Logger with request context
 */
class ContextLogger {
  constructor(requestId, userId = null) {
    this.requestId = requestId;
    this.userId = userId;
  }

  log(level, message, metadata = {}) {
    const context = {
      requestId: this.requestId,
      ...(this.userId && { userId: this.userId }),
      ...metadata,
    };
    logger[level](message, context);
  }

  error(message, metadata = {}) {
    this.log('error', message, metadata);
  }

  warn(message, metadata = {}) {
    this.log('warn', message, metadata);
  }

  info(message, metadata = {}) {
    this.log('info', message, metadata);
  }

  debug(message, metadata = {}) {
    this.log('debug', message, metadata);
  }
}

/**
 * Create logger with context
 */
function createContextLogger(requestId, userId = null) {
  return new ContextLogger(requestId, userId);
}

/**
 * Replace console methods with logger
 */
function replaceConsole() {
  console.log = (...args) => logger.info(args.join(' '));
  console.error = (...args) => logger.error(args.join(' '));
  console.warn = (...args) => logger.warn(args.join(' '));
  console.info = (...args) => logger.info(args.join(' '));
  console.debug = (...args) => logger.debug(args.join(' '));
}

module.exports = {
  logger,
  createContextLogger,
  replaceConsole,
};

