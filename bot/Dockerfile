FROM node:20-alpine

RUN apk add --no-cache bash gcompat redis

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --only=production

COPY fetch-conf.js .
COPY index.js .
COPY entrypoint.sh .
RUN chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]
