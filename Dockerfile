FROM node:14.21.3-bullseye-slim AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    g++ \
    make \
    git \
    libtool \
    automake \
    autoconf \
    openssl \
    libvips-dev \
    && rm -rf /var/lib/apt/lists/*

# package.json と yarn.lock だけ先にコピーしてキャッシュを活用する
COPY package.json yarn.lock ./

# install all dependencies including devDependencies
RUN yarn install --pure-lockfile

COPY . .

# Note also that prisma generate is automatically invoked when you're installing the @prisma/client npm package
RUN npx prisma generate

# Save production dependencies installed so we can later copy them in the production image
RUN yarn install --pure-lockfile --production && cp -R node_modules /tmp/node_modules

RUN yarn build

###########
FROM node:14.21.3-bullseye-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    tzdata \
    && cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/node_modules ./node_modules
COPY --from=builder /app/.blitz ./.blitz
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/package.json ./
COPY --from=builder /app/db ./

ENV PORT=8080
EXPOSE 8080

CMD [ "npm","run","start:prd" ]
