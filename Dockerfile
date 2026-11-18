FROM python:3-slim

RUN apt-get update && apt-get upgrade -y --no-install-recommends && rm -rf /var/lib/apt/lists/*

WORKDIR /api

RUN [ "useradd", "apiuser" ]

COPY learningsteps/api/requirements.txt .

RUN [ "pip", "install", "--no-cache-dir", "-r", "requirements.txt", "setuptools>=78.1.1", "msgpack>=1.2.3", "urllib3>=2.8.0" ]

COPY learningsteps/api/ .

USER apiuser
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

EXPOSE 8000