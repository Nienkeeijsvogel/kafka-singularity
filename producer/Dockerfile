FROM python:3
ENV PYTHONUNBUFFERED 1
RUN mkdir /code
WORKDIR /code
COPY requirements.txt /code/
RUN apt-get update -y
RUN apt-get install sudo
RUN sudo echo "Europe/Amsterdam" > /etc/timezone
RUN pip install -r requirements.txt
COPY producer.py /code/producer.py
CMD ["python",  "/code/producer.py"]