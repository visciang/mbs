FROM python:3.9.2-alpine

ENV PYTHONUNBUFFERED=TRUE

ADD .cache/*.pyz /app.pyz

ENTRYPOINT [ "/app.pyz" ]
