FROM node:20-alpine

RUN apk add --no-cache bash gcompat

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --only=production

COPY index.js .

CMD ["node", "index.js"]