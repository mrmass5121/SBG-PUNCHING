const blockedPaths = [
  /^\/supabase(?:\/.*)?$/i,
  /^\/functions(?:\/.*)?$/i,
  /^\/netlify(?:\/.*)?$/i,
  /^\/README\.md$/i,
  /^\/wrangler\.toml$/i,
  /^\/netlify\.toml$/i,
  /^\/vercel\.json$/i,
  /^\/_headers$/i,
  /^\/_redirects$/i,
  /^\/\.env\.example$/i
];

export async function onRequest(context) {
  const path = new URL(context.request.url).pathname;
  if (blockedPaths.some(pattern => pattern.test(path))) {
    return new Response("Not found", {
      status: 404,
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-store",
        "X-Robots-Tag": "noindex, nofollow, noarchive"
      }
    });
  }

  return context.next();
}
