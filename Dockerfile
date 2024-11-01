FROM debian:stable

WORKDIR /app

COPY *.sh .

RUN apt update && apt upgrade -y && apt install sudo -y
RUN useradd -m test && \
  echo "root:tester"| chpasswd && \
  echo "test:tester" | chpasswd && \
  adduser test sudo

USER test

CMD ["/bin/bash"] 
