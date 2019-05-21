FROM node:8-alpine as builder
WORKDIR /app
COPY . .
RUN npm i && npm run build
FROM nginx:alpine
EXPOSE 443
COPY --from=builder /app/public /usr/share/nginx/html
