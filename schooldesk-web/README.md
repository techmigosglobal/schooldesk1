# SchoolDesk Web

Separate Next.js web application for the public Arish Ville School website and the principal/coordinator portal.

1. Start the Docker-local stack with `scripts/local_supabase.sh prepare` and serve the API with `scripts/local_supabase.sh functions`.
2. Copy `.env.example` to `.env.local` (the example targets synthetic School A) and run `bun install` then `bun run dev`.
3. The current production deployment is on Vercel. For the Hostinger migration, deploy this directory as a Next.js Docker application in Coolify; keep Vercel available as rollback until the VPS version has passed the soak period.

## Vercel environment variables

In **Project Settings → Environment Variables**, add the following server-side variables for every environment you deploy (at least **Production**, and **Preview** if you use preview URLs):

```text
SCHOOLDESK_API_BASE_URL=https://api.arishville.com/functions/v1/api
SCHOOLDESK_API_ANON_KEY=<VPS Supabase anon JWT>
SCHOOLDESK_PUBLIC_SCHOOL_ID=<restored Arish Ville school UUID>
NEXT_PUBLIC_SITE_URL=https://arishville.com
SCHOOLDESK_MEDIA_CSP_ORIGINS=https://api.arishville.com
```

Set these for Production and Preview. The Supabase API gateway requires the anon key in `apikey` and `Authorization` headers, including for the public website endpoint and login. Keep the key server-side; never use a service-role key. Do not prefix `SCHOOLDESK_API_BASE_URL` or `SCHOOLDESK_API_ANON_KEY` with `NEXT_PUBLIC_`: browser requests go through Next.js server routes. Redeploy after saving environment variables because Vercel applies them to new deployments.

The portal calls the existing Edge API through `/api/backend/*`. The public website reads only `/website/public`, which exposes published website content and the dedicated `school-public-media` bucket.

## Coolify / Hostinger deployment

This is a Next.js server application: API route handlers, secure session cookies,
and server-side backend requests require the Node runtime. In Coolify, create a
Dockerfile-based application using `schooldesk-web` as the build context and
port `3000`; do not select the Static build pack.

Set these build arguments and runtime environment variables in Coolify after
the self-hosted backend and its public school record are restored. Store the
anon key as a protected server-side value:

```text
SCHOOLDESK_API_BASE_URL=https://api.arishville.com/functions/v1/api
SCHOOLDESK_API_ANON_KEY=<VPS Supabase anon JWT>
SCHOOLDESK_PUBLIC_SCHOOL_ID=<restored Arish Ville school UUID>
NEXT_PUBLIC_SITE_URL=https://arishville.com
SCHOOLDESK_MEDIA_CSP_ORIGINS=https://api.arishville.com
```

The first four values are required at build time and runtime. The media CSP
value is a space-separated allowlist read during the build. Never put a
Supabase service-role/secret key in this web application; its server routes
authenticate through the SchoolDesk API. Configure `arishville.com` and
`www.arishville.com` on the Coolify application only during the approved DNS
cutover. Until then, use Coolify's preview hostname and leave the Vercel
production deployment and DNS records in place for rollback.

## Web data and desktop verification

- List screens follow the API's `has_more` / `total` pagination instead of assuming a requested page size is honored. A failed page is reported rather than returning an incomplete ledger.
- Authenticated media URLs are normalized at the web proxy. Report downloads are resolved from the user's branch-scoped export history and fetched through the web server; missing legacy files must be regenerated using the existing report controls.
- Keep `NEXT_PUBLIC_SITE_URL=https://arishville.com` in production. Deployment aliases are not canonical school URLs. Public metadata includes the spaced and unspaced brand names; login and portal routes are marked `noindex`.
- Run `bun test`, `npm run typecheck`, and `npm run build` from this directory. Verify the production build in a desktop browser, including complete fee counts, a downloaded receipt CSV, Quick Search, current-module refresh, keyboard dialogs, and session refresh.
- Exercise failure/retry and form-submission checks with intercepted browser requests or an isolated test backend. Do not create financial transactions or publish school content merely to smoke-test a production connection.
