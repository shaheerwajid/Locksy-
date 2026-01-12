/*
 * Email Consumer
 * Processes queued emails and sends via SMTP
 */

const MessageConsumer = require('../queue/consumer');
const nodemailer = require('nodemailer');
const config = require('../../config');

class EmailConsumer extends MessageConsumer {
  constructor() {
    super('email_queue', {
      prefetch: 5, // Process up to 5 emails at a time
      maxRetries: 3,
    });

    // Initialize email transporter
    this.transporter = null;
    this.initializeTransporter();
  }

  /**
   * Initialize email transporter
   */
  initializeTransporter() {
    try {
      const emailConfig = config.email;
      
      if (!emailConfig.user || !emailConfig.password) {
        console.warn('Email: SMTP credentials not configured');
        return;
      }

      this.transporter = nodemailer.createTransport({
        host: emailConfig.host,
        port: emailConfig.port,
        secure: emailConfig.port === 465, // true for 465, false for other ports
        auth: {
          user: emailConfig.user,
          pass: emailConfig.password,
        },
      });

      console.log('Email: Transporter initialized');
    } catch (error) {
      console.error('Email: Failed to initialize transporter', error.message);
    }
  }

  /**
   * Process email message
   */
  async processMessage(message, handler) {
    if (!this.transporter) {
      console.warn('Email: Transporter not initialized, skipping email');
      return true; // Acknowledge to remove from queue
    }

    try {
      const { data } = message;
      const { to, subject, html, text, from, attachments, priority } = data;

      // Prepare email options
      const mailOptions = {
        from: from || config.email.user,
        to: Array.isArray(to) ? to.join(',') : to,
        subject,
        html,
        text,
        attachments,
        priority: priority === 'high' ? 'high' : 'normal',
      };

      // Send email
      const info = await this.transporter.sendMail(mailOptions);
      console.log(`Email: Successfully sent to ${to}: ${info.messageId}`);
      return true;
    } catch (error) {
      console.error('Email: Error sending email', error.message);
      return false;
    }
  }
}

module.exports = EmailConsumer;

