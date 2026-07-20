# SchoolDesk Web

Separate Next.js web application for the public ArishVille School website and the principal/coordinator portal.

1. Copy `.env.example` to `.env.local` and provide the existing Edge API URL and ArishVille School UUID.
2. Run `bun install` then `bun run dev`.
3. Deploy this directory as its own Vercel project. Configure production and preview variables separately; no service-role key belongs in Vercel browser variables.

The portal calls the existing Edge API through `/api/backend/*`. The public website reads only `/website/public`, which exposes published website content and the dedicated `school-public-media` bucket.
