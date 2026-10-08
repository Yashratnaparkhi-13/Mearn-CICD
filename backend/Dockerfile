# ---------- Stage 1: install dependencies ----------
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# ---------- Stage 2: final runtime image ----------
FROM node:18-alpine AS runner
WORKDIR /app

# Run as a non-root user for better security
RUN addgroup -g 1001 -S nodejs && adduser -S expressjs -u 1001

ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY . .

USER expressjs

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "src/server.js"]
