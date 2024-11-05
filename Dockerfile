FROM debian:latest

WORKDIR /app

RUN rm /bin/sh &&  ln -s /bin/bash /bin/sh

RUN apt update && apt upgrade -y && apt install sudo adduser curl -y
RUN useradd -m test && \
  echo "root:tester"| chpasswd && \
  echo "test:tester" | chpasswd && \
  adduser test sudo

# RUN sudo apt install fish -y
# RUN echo "tester" | sudo -u test chsh -s $(which fish)
# RUN sudo -u test fish

RUN sudo curl -O https://raw.githubusercontent.com/Edzemundo/penguin_setup/refs/heads/main/starter.sh

USER test

CMD ["/bin/bash"]
