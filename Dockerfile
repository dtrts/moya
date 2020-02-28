FROM node:10
WORKDIR /app

COPY package.json ./
COPY yarn.lock ./
RUN yarn

ADD . .

CMD node src/pilot.js
