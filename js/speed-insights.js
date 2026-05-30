/**
 * Vercel Speed Insights initialization for vanilla JavaScript
 * This script injects the Speed Insights tracking code to measure web vitals
 * 
 * Based on official Vercel Speed Insights documentation:
 * https://vercel.com/docs/speed-insights/quickstart
 */

// Initialize the Speed Insights queue
window.si = window.si || function () { 
  (window.siq = window.siq || []).push(arguments); 
};

// Load the Speed Insights script
(function() {
  const script = document.createElement('script');
  script.defer = true;
  script.src = '/_vercel/speed-insights/script.js';
  
  // Add error handling
  script.onerror = function() {
    console.warn('[Speed Insights] Failed to load script. This is expected in development.');
  };
  
  document.head.appendChild(script);
})();
