FROM python:3.9.2-alpine

ENV PYTHONUNBUFFERED=TRUE

ADD .cache/MBS_DIR_PYTHON_NATIVE_APP/*.pyz /app.pyz

ENTRYPOINT [ "/app.pyz" ]
