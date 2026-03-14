FROM node:20-alpine

RUN apk add --no-cache openssl bash

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --production

COPY src/ ./src/
COPY config/ ./config/
COPY scripts/ ./scripts/

RUN chmod +x scripts/*.sh

EXPOSE 4840

HEALTHCHECK --interval=10s --timeout=10s --start-period=30s --retries=5 \
  CMD node -e "const net = require('net'); const s = net.createConnection({port: process.env.OPCUA_PORT || 4840}, () => { s.end(); process.exit(0); }); s.on('error', () => process.exit(1));"

CMD ["node", "src/index.js"]
