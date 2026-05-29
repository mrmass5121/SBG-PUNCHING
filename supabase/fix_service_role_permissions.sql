-- Run this in the Supabase SQL Editor if Vercel/Cloudflare form submissions return:
-- HTTP 500: permission denied for table production_reviews
-- or permission denied for table inquiries.
--
-- The public browser still cannot approve or manage rows. These grants only allow
-- the server-side API, authenticated with SUPABASE_SERVICE_ROLE_KEY, to insert.

grant usage on schema public to service_role;
grant insert on public.inquiries to service_role;
grant insert on public.production_reviews to service_role;
