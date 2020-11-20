FROM node:14-slim as installer

WORKDIR /usr/src/app

COPY ./package*.json ./

RUN npm install

FROM node:14-slim as builder

COPY --from=installer /usr/src/app /usr/src/app

WORKDIR /usr/src/app

COPY . ./

USER node

EXPOSE 3000

CMD ["npm", "start"]


