FROM alpine:3.9

ENV APP_HOME /app
ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

# RUN mkdir $APP_HOME не требуется, директория будет создана автоматически
WORKDIR $APP_HOME

COPY Gemfile* $APP_HOME/

RUN apk update \
    && apk add \
        ruby ruby-json ruby-bundler \
    && apk add \
        --virtual .build-deps build-base ruby-dev \
    && gem install bundler --no-ri --no-rdoc \
    && bundle install \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

COPY . $APP_HOME

CMD ["puma"]
