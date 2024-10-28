# syntax=docker/dockerfile:1.4
FROM --platform=linux/x86_64 python:3.11-slim-bookworm as cicd

WORKDIR /app

COPY pyproject.toml poetry.lock README.md ./

RUN pip install poetry==1.5.1

COPY src ./src

RUN poetry install --without=dev --no-root


# syntax=docker/dockerfile:1.4
FROM --platform=linux/x86_64 python:3.11-slim-bookworm as runner

WORKDIR /app

COPY pyproject.toml poetry.lock README.md ./

RUN pip install poetry==1.5.1

COPY src ./src

RUN poetry install --without=dev --no-root

RUN poetry build &&  \
    poetry run pip install ./dist/*.whl

