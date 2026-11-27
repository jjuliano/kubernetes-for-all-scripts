FROM python:3.12-alpine
WORKDIR /app
COPY main.py .
ENV SERVICE_NAME=registry PORT=8080
EXPOSE 8080
CMD ["python", "-u", "main.py"]
