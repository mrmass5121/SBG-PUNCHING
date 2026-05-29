/**
 * Vercel Speed Insights initialization
 * This script injects the Speed Insights tracking code to measure web vitals
 */
import { injectSpeedInsights } from './vercel-speed-insights.mjs';

// Initialize Speed Insights
injectSpeedInsights({
  debug: false, // Set to true for development debugging
});
