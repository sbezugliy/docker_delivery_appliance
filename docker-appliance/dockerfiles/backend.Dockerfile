FROM ruby:3.1.0-alpine3.15 as build_base


FROM build_base as development


FROM development as test


FROM build_base as production
