FROM ubuntu:latest
# FROM fedora:latest

WORKDIR /app

COPY . /app

SHELL ["/bin/bash", "-c"]

# RUN dnf update -y && dnf upgrade -y
RUN apt update -y && apt upgrade -y

# RUN dnf install sudo passwd -y
RUN apt install sudo passwd -y

# Fix Windows line endings in scripts
RUN sed -i 's/\r$//' /app/*.sh

# Create test user
RUN useradd -m -s /bin/bash tester
RUN echo "tester:tester" | chpasswd

# Debian uses sudo while Fedora uses wheel
# RUN usermod -aG wheel tester
RUN usermod -aG sudo tester

# Configure passwordless sudo for wheel/sudo group
# RUN echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN echo "%sudo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Change ownership of files to tester
RUN chown -R tester:tester /app

# Make scripts executable
RUN chmod +x /app/*.sh

USER tester

# Run setup with tester user, or start shell for manual testing
# CMD [ "sudo", "./setup.sh", "tester" ]
CMD [ "bash" ]
