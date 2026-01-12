/*
 * OTP Email Service
 * Sends OTP verification emails to users
 */

const { queueEmail } = require('./producer');
const { isConnected } = require('../queue/rabbitmq');
const nodemailer = require('nodemailer');
const config = require('../../config');

/**
 * Send email directly (fallback when RabbitMQ is unavailable)
 */
async function sendEmailDirectly(emailData) {
  try {
    const emailConfig = config.email;
    
    if (!emailConfig.user || !emailConfig.password) {
      throw new Error('SMTP credentials not configured');
    }

    const transporter = nodemailer.createTransport({
      host: emailConfig.host,
      port: emailConfig.port,
      secure: emailConfig.port === 465,
      auth: {
        user: emailConfig.user,
        pass: emailConfig.password,
      },
    });

    const info = await transporter.sendMail({
      from: emailData.from || emailConfig.user,
      to: emailData.to,
      subject: emailData.subject,
      html: emailData.html,
      text: emailData.text,
      priority: emailData.priority === 'high' ? 'high' : 'normal',
    });

    console.log(`Email: Successfully sent directly to ${emailData.to}: ${info.messageId}`);
    return true;
  } catch (error) {
    console.error('Email: Error sending email directly', error.message);
    throw error;
  }
}

/**
 * Send OTP email to user
 */
async function sendOTPEmail(email, nombre, otpCode) {
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
        .otp-code { 
          font-size: 36px; 
          font-weight: bold; 
          color: #4CAF50; 
          text-align: center;
          padding: 20px;
          background: white;
          border-radius: 8px;
          letter-spacing: 10px;
          margin: 20px 0;
          border: 2px dashed #4CAF50;
        }
        .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
        .warning { background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #ffc107; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Locksy - Email Verification</h1>
        </div>
        <div class="content">
          <h2>Hello ${nombre}!</h2>
          <p>Thank you for registering with Locksy. Please use the following verification code to complete your registration:</p>
          <div class="otp-code">${otpCode}</div>
          <div class="warning">
            <strong>⚠️ Important:</strong> This code will expire in 15 minutes.
          </div>
          <p>If you didn't request this code, please ignore this email.</p>
          <div class="footer">
            <p>© ${new Date().getFullYear()} Locksy. All rights reserved.</p>
          </div>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
    Hello ${nombre}!
    
    Thank you for registering with Locksy. Please use the following verification code to complete your registration:
    
    ${otpCode}
    
    ⚠️ Important: This code will expire in 15 minutes.
    
    If you didn't request this code, please ignore this email.
    
    © ${new Date().getFullYear()} Locksy. All rights reserved.
  `;

  const emailData = {
    to: email,
    subject: 'Verify Your Email - Locksy',
    html: html,
    text: text,
    from: process.env.EMAIL_FROM || process.env.EMAIL_USER || 'noreply@locksy.com',
    priority: 'high',
  };

  // Try to queue email, fallback to direct send if RabbitMQ is unavailable
  try {
    if (isConnected()) {
      const queued = await queueEmail(emailData);
      if (!queued) {
        // Queue failed, send directly
        console.warn('[OTP] Failed to queue email, sending directly');
        await sendEmailDirectly(emailData);
      }
    } else {
      console.warn('[OTP] RabbitMQ not connected, sending email directly');
      await sendEmailDirectly(emailData);
    }
  } catch (error) {
    // If queuing fails, try direct send as fallback
    console.warn('[OTP] Error queuing email, attempting direct send:', error.message);
    try {
      await sendEmailDirectly(emailData);
    } catch (directError) {
      console.error('[OTP] Failed to send email both via queue and directly:', directError.message);
      throw directError;
    }
  }
}

/**
 * Send password reset OTP email to user
 */
async function sendPasswordResetOTPEmail(email, nombre, otpCode) {
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #FF6B6B; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
        .otp-code { 
          font-size: 36px; 
          font-weight: bold; 
          color: #FF6B6B; 
          text-align: center;
          padding: 20px;
          background: white;
          border-radius: 8px;
          letter-spacing: 10px;
          margin: 20px 0;
          border: 2px dashed #FF6B6B;
        }
        .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
        .warning { background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #ffc107; }
        .security { background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #2196F3; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Locksy - Password Reset</h1>
        </div>
        <div class="content">
          <h2>Hello ${nombre}!</h2>
          <p>We received a request to reset your password. Please use the following verification code to proceed:</p>
          <div class="otp-code">${otpCode}</div>
          <div class="warning">
            <strong>⚠️ Important:</strong> This code will expire in 15 minutes.
          </div>
          <div class="security">
            <strong>🔒 Security Notice:</strong> If you didn't request a password reset, please ignore this email. Your password will remain unchanged.
          </div>
          <p>Enter this code in the app to reset your password.</p>
          <div class="footer">
            <p>© ${new Date().getFullYear()} Locksy. All rights reserved.</p>
          </div>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
    Hello ${nombre}!
    
    We received a request to reset your password. Please use the following verification code to proceed:
    
    ${otpCode}
    
    ⚠️ Important: This code will expire in 15 minutes.
    
    🔒 Security Notice: If you didn't request a password reset, please ignore this email. Your password will remain unchanged.
    
    Enter this code in the app to reset your password.
    
    © ${new Date().getFullYear()} Locksy. All rights reserved.
  `;

  const emailData = {
    to: email,
    subject: 'Reset Your Password - Locksy',
    html: html,
    text: text,
    from: process.env.EMAIL_FROM || process.env.EMAIL_USER || 'noreply@locksy.com',
    priority: 'high',
  };

  // Try to queue email, fallback to direct send if RabbitMQ is unavailable
  try {
    if (isConnected()) {
      const queued = await queueEmail(emailData);
      if (!queued) {
        console.warn('[Password Reset] Failed to queue email, sending directly');
        await sendEmailDirectly(emailData);
      }
    } else {
      console.warn('[Password Reset] RabbitMQ not connected, sending email directly');
      await sendEmailDirectly(emailData);
    }
  } catch (error) {
    console.warn('[Password Reset] Error queuing email, attempting direct send:', error.message);
    try {
      await sendEmailDirectly(emailData);
    } catch (directError) {
      console.error('[Password Reset] Failed to send email both via queue and directly:', directError.message);
      throw directError;
    }
  }
}

module.exports = {
  sendOTPEmail,
  sendPasswordResetOTPEmail,
};

