# syntax=docker/dockerfile:1.4
FROM --platform=linux/x86_64 python:3.11-slim-bookworm as deps

WORKDIR /app

COPY pyproject.toml poetry.lock README.md ./

RUN pip install poetry==1.5.1 && \
    poetry config virtualenvs.in-project true && \
    poetry config virtualenvs.create true

COPY src ./src

RUN poetry install --without=dev --no-root

RUN poetry build &&  \
    poetry run pip install ./dist/*.whl

FROM deps as runner

ENTRYPOINT ["/app/.venv/bin/python", "-m", "gunicorn", "src.app:app", "--preload", \
    "--bind", ":8080", \
    "--workers", "3", \
    "--thread", "8", \
    "--worker-class", "uvicorn.workers.UvicornWorker", \
    "--log-level", "info", \
    "--access-logfile", "/dev/stdout", \
    "--error-logfile", "/dev/stderr"]
