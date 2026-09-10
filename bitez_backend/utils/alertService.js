const sendEmail = require('./email');

/**
 * Health Alerting Service
 * Monitors API rate limit violations and background cron failures.
 * Sends email alerts via Nodemailer with cooldown throttling.
 */
class AlertService {
  constructor() {
    // Array of { timestamp: number, ip: string, path: string }
    this.rateLimitViolations = [];

    // Cooldown trackers (timestamps in ms)
    this.lastRateLimitAlertTime = 0;
    this.lastCronAlertTime = {};

    // Cooldown windows
    this.RATE_LIMIT_ALERT_COOLDOWN_MS = 15 * 60 * 1000; // 15 mins
    this.CRON_ALERT_COOLDOWN_MS = 60 * 60 * 1000;       // 60 mins
    this.VIOLATION_WINDOW_MS = 5 * 60 * 1000;           // 5 mins
    this.VIOLATION_THRESHOLD = 5;                        // >5 hits in 5 mins triggers alert
  }

  /**
   * Records a 429 rate limit violation and checks if alert threshold is reached.
   * @param {string} ip - Client IP
   * @param {string} path - Request endpoint
   * @param {string} limiterName - Limiter identifier
   */
  async recordRateLimitViolation(ip, path, limiterName = 'General') {
    const now = Date.now();
    this.rateLimitViolations.push({ timestamp: now, ip, path, limiterName });

    // Prune violations older than the window
    this.rateLimitViolations = this.rateLimitViolations.filter(
      (v) => now - v.timestamp <= this.VIOLATION_WINDOW_MS
    );

    console.warn(`⚠️ [RateLimit] ${limiterName} limit exceeded: IP=${ip}, Path=${path} (Recent violations in 5m: ${this.rateLimitViolations.length})`);

    // Check if threshold exceeded and cooldown expired
    if (
      this.rateLimitViolations.length >= this.VIOLATION_THRESHOLD &&
      now - this.lastRateLimitAlertTime >= this.RATE_LIMIT_ALERT_COOLDOWN_MS
    ) {
      this.lastRateLimitAlertTime = now;
      await this._sendRateLimitAlert(this.rateLimitViolations);
    }
  }

  /**
   * Sends email alert when rate limits are repeatedly exceeded.
   */
  async _sendRateLimitAlert(recentViolations) {
    const adminEmail = process.env.ADMIN_ALERT_EMAIL || process.env.EMAIL_USER || 'admin@bitez.app';
    const violationSummary = recentViolations
      .slice(-10)
      .map((v) => `• [${new Date(v.timestamp).toLocaleTimeString()}] ${v.limiterName} on ${v.path} from IP ${v.ip}`)
      .join('\n');

    const message = `🚨 Bitez Health Alert: High Rate Limit Activity Detected!

Over the past 5 minutes, ${recentViolations.length} rate limit violations have been recorded across the Bitez API.

Recent incidents:
${violationSummary}

Please check if external quotas (Google Gemini Vision/Chat or Spoonacular) are under elevated load or if an IP is attempting excessive requests.

Server Timestamp: ${new Date().toISOString()}`;

    try {
      await sendEmail({
        email: adminEmail,
        subject: `🚨 [Bitez Alert] High Rate Limit Violations (${recentViolations.length} in 5m)`,
        message,
      });
      console.log(`📧 Health alert email sent to ${adminEmail} for rate limit spikes.`);
    } catch (err) {
      console.error('Failed to send rate limit alert email:', err.message);
    }
  }

  /**
   * Notifies admin when a background cron/scheduler fails.
   * @param {string} cronName - Name of the cron task
   * @param {Error|string} error - Error encountered
   */
  async notifyCronFailure(cronName, error) {
    const now = Date.now();
    const lastAlert = this.lastCronAlertTime[cronName] || 0;

    console.error(`🔥 [Cron Failure] ${cronName} failed:`, error?.message || error);

    if (now - lastAlert < this.CRON_ALERT_COOLDOWN_MS) {
      console.log(`ℹ️ Suppressing duplicate cron alert for "${cronName}" within cooldown.`);
      return;
    }

    this.lastCronAlertTime[cronName] = now;
    const adminEmail = process.env.ADMIN_ALERT_EMAIL || process.env.EMAIL_USER || 'admin@bitez.app';
    const errorDetails = error?.stack || error?.message || String(error);

    const message = `🔥 Bitez Health Alert: Background Cron Job Failure!

The following scheduled job has failed:
Job Name: ${cronName}
Time: ${new Date().toISOString()}

Error Details:
${errorDetails}

Please inspect server logs and database connectivity.`;

    try {
      await sendEmail({
        email: adminEmail,
        subject: `🔥 [Bitez Alert] Cron Failure: ${cronName}`,
        message,
      });
      console.log(`📧 Cron failure alert email sent to ${adminEmail}.`);
    } catch (err) {
      console.error('Failed to send cron failure alert email:', err.message);
    }
  }
}

const alertService = new AlertService();
module.exports = alertService;
