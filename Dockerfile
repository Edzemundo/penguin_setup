FROM ubuntu:latest

WORKDIR /app

SHELL ["/bin/bash", "-c"]

RUN apt update && apt upgrade -y

RUN apt install adduser sudo -y

RUN adduser --gecos "" tester
RUN adduser tester sudo
RUN echo "tester:tester" | chpasswd

USER tester

CMD [ "sudo", "./setup.sh", "tester" ]
