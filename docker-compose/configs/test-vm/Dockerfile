# Simulated Target VM with SSH enabled
FROM ubuntu:24.04

# Avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install SSH, sudo, and basic diagnostic tools
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    gnupg \
    iproute2 \
    iputils-ping \
    netcat-openbsd \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir /var/run/sshd
RUN echo 'root:rootpassword' | chpasswd
RUN useradd -m -s /bin/bash testuser && echo 'testuser:testpassword' | chpasswd
RUN usermod -aG sudo testuser

# Set up SSH configuration (allow password auth)
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

EXPOSE 22

# Run SSH daemon in the foreground
CMD ["/usr/sbin/sshd", "-D"]
