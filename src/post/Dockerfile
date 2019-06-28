FROM python:3.6.0-alpine

WORKDIR /app
ADD . /app

RUN apk --update add --virtual build-deps \
                        gcc libc-dev \
    && pip install -r /app/requirements.txt

ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

ENTRYPOINT ["python3", "post_app.py"]
