FROM ruby:alpine3.9

ENV APP_HOME /reddit
WORKDIR $APP_HOME

ADD . $APP_HOME

RUN apk update \
    && apk add \
        --virtual .build-deps build-base \
    && bundle install \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

RUN bundle install

CMD ["puma"]
