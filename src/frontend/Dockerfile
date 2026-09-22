# --- build stage ---
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY . .

ARG VITE_APP_VERSION=0.0.0-local
ENV VITE_APP_VERSION=${VITE_APP_VERSION}
ENV VITE_API_BASE_URL=/api

RUN npm run build

# --- runtime stage: static files served by nginx, non-root ---
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

USER 101

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O- http://127.0.0.1:8080/ || exit 1
