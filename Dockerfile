# Stage 1 : Builder
FROM node:24-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci && npm cache clean --force

# Copier TOUS les fichiers de config essentiels
COPY tsconfig*.json nest-cli.json eslint.config.mjs ./
COPY src ./src

# Builder l'application
# Vérifier que dist a bien été créé 
# Nettoyer les devDependencies
RUN npm run build && \
    ls -la /app/dist && \
    npm prune --omit=dev && npm cache clean --force

# Stage 2 : Runtime
FROM node:24-alpine

RUN apk add --no-cache dumb-init && \
    addgroup -g 1001 -S nodejs && \
    adduser -S nestjs -u 1001

WORKDIR /app

# Copier node_modules
COPY --from=builder --chown=nestjs:nodejs /app/node_modules ./node_modules

# Copier dist
COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist

# Copier package.json
COPY --chown=nestjs:nodejs package*.json ./

USER nestjs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main"]