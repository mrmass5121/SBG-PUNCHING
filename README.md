# SBG Punching Premium Showcase

Static industrial showcase app with a Supabase backend, secure admin dashboard, live production gallery, inquiry capture, PWA support, and responsive UI.

## Setup

1. Create a Supabase project.
2. Run `supabase/schema.sql` in the Supabase SQL editor.
   - If the project already exists and form submissions return `permission denied for table production_reviews` or `permission denied for table inquiries`, run `supabase/fix_service_role_permissions.sql`.
3. Create the first admin user in Supabase Authentication.
4. Promote that user:

```sql
update public.profiles set role = 'admin' where email = 'admin@example.com';
```

5. Optional: create standard users. They can view the admin dashboard, records, inquiries, reviews, and media, and they can add daily or marketing production uploads. They cannot edit, hide/show, delete, approve reviews, mark inquiries, or manage showcase notes.

```sql
update public.profiles set role = 'standard' where email = 'uploader@example.com';
```

6. Edit `js/config.js` with the Supabase project URL, publishable/anon key, Cloudflare Turnstile site key, and any public contact settings.
7. Add these server-side environment variables in your host: `TURNSTILE_SECRET_KEY`, `SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY`.
8. Keep the service-role key and Turnstile secret only in Vercel environment variables or Cloudflare Pages secrets. Never put them in `js/config.js`.
9. Disable public signups unless you intentionally want self-service accounts.
10. Enable email confirmation and MFA for admin users in Supabase Auth.
11. Deploy the folder to Vercel or Cloudflare Pages. `vercel.json` and `api/*` provide the Vercel settings and server-side form handlers; `wrangler.toml`, `_headers`, `_redirects`, `functions/_middleware.js`, and `functions/api/*` provide the Cloudflare Pages settings and server-side form handlers.

Do not put service-role keys, secret keys, database passwords, or personal access tokens in frontend files. The browser app only uses the public publishable/anon key; admin access is enforced by Supabase Auth, RLS, and Storage policies.

## Vercel Deployment

This project can deploy to Vercel as a static site with Vercel Functions.

1. Import this repository/folder into Vercel.
2. Use these project settings:
   - Framework preset: Other
   - Build command: `npm run build`
   - Output directory: `dist`
3. Add environment variables for Production, Preview, and Development if needed:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `TURNSTILE_SECRET_KEY`
4. Deploy. The public app calls `/api/submit-inquiry` and `/api/submit-review`, which are handled by files in `api/`.

`vercel.json` applies security headers, no-store headers for admin/config/API paths, redirects `/admin` to the login page, rewrites product routes to the static app, and returns 404 for internal deployment/source files.

## Cloudflare With Vercel

Cloudflare Turnstile remains supported on Vercel. Add your Vercel preview and production domains to the Turnstile widget's allowed hostnames in Cloudflare.

If your domain DNS stays in Cloudflare:

1. Add the domain to the Vercel project first.
2. In Vercel, inspect the domain and copy the exact DNS records Vercel recommends.
3. Add those records in Cloudflare DNS.
4. Keep the Cloudflare proxy disabled until Vercel verifies the domain and issues SSL.
5. If you later enable the Cloudflare proxy, use Full (strict) SSL and bypass caching for `/api/*`, `/admin/*`, `/js/config.js`, and service-worker updates.

Vercel generally recommends using Vercel DNS instead of placing Cloudflare as a reverse proxy in front of Vercel. If you keep Cloudflare in front for DNS, WAF, or Turnstile workflows, test form submissions after every DNS/proxy change.

## Cloudflare Pages Deployment

Cloudflare Pages is still supported.

1. Deploy this folder to Cloudflare Pages.
2. Set build output directory to `.`.
3. Add Cloudflare Pages secrets:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `TURNSTILE_SECRET_KEY`

`wrangler.toml`, `_headers`, `_redirects`, `functions/_middleware.js`, and `functions/api/*` keep the existing Cloudflare Pages deployment path working.

## Public Form Security

Customer inquiries and product reviews are submitted through server-side handlers under `/api` so Cloudflare Turnstile can be verified server-side before anything reaches Supabase. Reviews are saved as pending by default and only appear on the public gallery after an admin approves them in `/admin`.

If `turnstileSiteKey` or the host environment variables/secrets are missing, the production security path is incomplete. Do not rely on browser-only CAPTCHA checks.

## Admin

Open `/admin/login.html`, sign in with the Supabase admin account, and add production entries. Public marketing entries sync to the homepage gallery in real time.

Daily production uploads go to the private `production-media-private` bucket and are loaded in the admin dashboard with short-lived signed URLs. Marketing uploads go to the public `production-media-public` bucket.

If you already uploaded files to the old `production-media` bucket, move public marketing files into `production-media-public` and private/internal files into `production-media-private`, then update each `productions.media` JSON object with its `bucket` and `private` fields.

## Production Notes

- Run Supabase Security Advisor after every schema change.
- Keep RLS enabled on every exposed table.
- Keep the service-role/secret key backend-only.
- Keep Turnstile enabled on inquiries and reviews before heavy traffic; the database trigger slows repeat phone-number spam but does not replace real bot protection.
- Keep uploads inside the configured MIME and size policies in `supabase/schema.sql`.
- Enable Leaked password protection in Supabase Auth settings if your plan supports it.
- Pin third-party CDN script versions or self-host them before a high-security launch.

