FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache bash docker-cli

COPY package.json package-lock.json ./
RUN npm ci --only=production

COPY index.js .

CMD ["node", "index.js"]