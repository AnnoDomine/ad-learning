FROM python:3-slim

WORKDIR /api

RUN [ "useradd", "apiuser" ]

COPY learningsteps/api/requirements.txt .

RUN [ "pip", "install", "--no-cache-dir", "-r", "requirements.txt" ]

COPY learningsteps/api/ .

USER apiuser
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

EXPOSE 8000