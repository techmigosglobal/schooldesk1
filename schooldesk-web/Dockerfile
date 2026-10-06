FROM node:24-bookworm-slim AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:24-bookworm-slim AS builder
WORKDIR /app
ARG SCHOOLDESK_API_BASE_URL
ARG SCHOOLDESK_API_ANON_KEY
ARG SCHOOLDESK_PUBLIC_SCHOOL_ID
ARG NEXT_PUBLIC_SITE_URL
ARG SCHOOLDESK_MEDIA_CSP_ORIGINS
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    SCHOOLDESK_API_BASE_URL=${SCHOOLDESK_API_BASE_URL} \
    SCHOOLDESK_API_ANON_KEY=${SCHOOLDESK_API_ANON_KEY} \
    SCHOOLDESK_PUBLIC_SCHOOL_ID=${SCHOOLDESK_PUBLIC_SCHOOL_ID} \
    NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL} \
    SCHOOLDESK_MEDIA_CSP_ORIGINS=${SCHOOLDESK_MEDIA_CSP_ORIGINS}
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN test -n "$SCHOOLDESK_API_BASE_URL" \
    && test -n "$SCHOOLDESK_API_ANON_KEY" \
    && test -n "$SCHOOLDESK_PUBLIC_SCHOOL_ID" \
    && test -n "$NEXT_PUBLIC_SITE_URL" \
    && npm run build

FROM node:24-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
RUN groupadd --system --gid 1001 nodejs \
    && useradd --system --uid 1001 --gid nodejs nextjs
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
