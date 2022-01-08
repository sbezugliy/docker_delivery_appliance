FROM node:lts-alpine as build_base

FROM build_base as development


FROM development as test


FROM build_base as production
