# syntax=docker/dockerfile:1.4
FROM --platform=linux/x86_64 python:3.11-slim-bookworm as deps

WORKDIR /app

RUN pip install poetry==1.5.1

COPY pyproject.toml poetry.lock ./

RUN poetry config virtualenvs.create false

RUN poetry install
