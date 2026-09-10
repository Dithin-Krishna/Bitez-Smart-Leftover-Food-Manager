const assert = require('assert');
const alertService = require('../utils/alertService');
const rateLimiters = require('../middleware/rateLimiters');

async function runTests() {
  console.log('🧪 Testing Rate Limiting & Health Alerting Service...');

  // 1. Verify limiters are properly exported
  assert(rateLimiters.geminiLimiter, 'geminiLimiter must be exported');
  assert(rateLimiters.recipeLimiter, 'recipeLimiter must be exported');
  assert(rateLimiters.authLimiter, 'authLimiter must be exported');
  assert(rateLimiters.apiLimiter, 'apiLimiter must be exported');
  console.log('  ✅ Rate limiters exported successfully');

  // 2. Test AlertService violation recording
  const initialViolations = alertService.rateLimitViolations.length;
  await alertService.recordRateLimitViolation('127.0.0.1', '/api/vision/detect', 'Gemini AI');
  assert.strictEqual(
    alertService.rateLimitViolations.length,
    initialViolations + 1,
    'Violation should be recorded'
  );
  console.log('  ✅ Violation recorded in AlertService');

  // 3. Test Cron failure alert throttling
  let cronErrorLogged = false;
  try {
    await alertService.notifyCronFailure('Test Cron Scheduler', new Error('Simulated DB timeout'));
    cronErrorLogged = true;
  } catch (e) {
    cronErrorLogged = false;
  }
  assert(cronErrorLogged, 'Cron failure notification executed without crash');
  console.log('  ✅ Cron failure alerting executed gracefully');

  console.log('🎉 All Backend Rate Limiting & Alerting tests passed!');
}

runTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
