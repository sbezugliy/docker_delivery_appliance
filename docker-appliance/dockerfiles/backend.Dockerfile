FROM ruby:3.1.0-alpine as build_base

RUN apk update && apk add bash \
wget git build-base alpine-sdk \
postgresql-client libpq-dev \
openssl openssl-dev \
imagemagick imagemagick-dev

COPY --chmod=+x /sbin/entrypoints/backend_dev /usr/local/sbin/entrypoint
COPY --chmod=+x /sbin/database/pg_createuser /usr/local/sbin/pg_createuser

RUN mkdir -p /opt/app
WORKDIR /opt/app
RUN ls -la /usr/local/sbin/

FROM build_base as development
WORKDIR /opt/app

FROM development as test
WORKDIR /opt/app

FROM build_base as production
WORKDIR /opt/app
