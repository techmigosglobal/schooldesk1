# SchoolDesk Web

Separate Next.js web application for the public Arish Ville School website and the principal/coordinator portal.

1. Copy `.env.example` to `.env.local` and provide the existing Edge API URL and Arish Ville School UUID.
2. Run `bun install` then `bun run dev`.
3. Deploy this directory as its own Vercel project. Configure production and preview variables separately; no service-role key belongs in Vercel browser variables.

## Vercel environment variables

In **Project Settings → Environment Variables**, add the following server-side variables for every environment you deploy (at least **Production**, and **Preview** if you use preview URLs):

```text
SCHOOLDESK_API_BASE_URL=https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api
SCHOOLDESK_PUBLIC_SCHOOL_ID=b3409710-78ac-446d-b8f5-45c58d72a004
NEXT_PUBLIC_SITE_URL=https://your-production-domain.example
```

`SCHOOLDESK_API_BASE_URL` is required. Do not prefix it with `NEXT_PUBLIC_`: it must remain available only to the Next.js server, which proxies browser requests through `/api/backend/*`. Redeploy after saving environment variables because Vercel applies them to new deployments.

The portal calls the existing Edge API through `/api/backend/*`. The public website reads only `/website/public`, which exposes published website content and the dedicated `school-public-media` bucket.
