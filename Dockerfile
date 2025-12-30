# FROM ubuntu:latest
FROM fedora:latest

WORKDIR /app

COPY . /app

SHELL ["/bin/bash", "-c"]

RUN dnf update -y && dnf upgrade -y

RUN dnf install sudo chsh -y

# Fix Windows line endings in scripts
RUN sed -i 's/\r$//' /app/*.sh

RUN useradd -m -s /bin/bash tester
RUN echo "tester:tester" | chpasswd
RUN usermod -aG wheel tester

# Configure passwordless sudo for wheel group
RUN echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Change ownership of files to tester
RUN chown -R tester:tester /app

# Make scripts executable
# RUN chmod +x /app/*.sh

USER tester

# CMD [ "sudo", "./setup.sh", "tester" ]
CMD [ "sh" ]
