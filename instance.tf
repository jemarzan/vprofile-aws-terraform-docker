# ---------------------------------------------------------------------------
# EC2 Instance – vprofile Docker host
# ---------------------------------------------------------------------------

locals {
  # Use provided subnet_id if given, otherwise pick the first resolved subnet
  resolved_subnet_id = var.subnet_id != "" ? var.subnet_id : tolist(data.aws_subnets.public.ids)[0]

  # Inline docker-compose.yml — embedded verbatim so the instance is
  # fully self-contained without any external file dependency at plan time.
  docker_compose_content = <<-COMPOSE
    services:
        vprodb:
            image: jemdevops/vprofiledb:latest
            container_name: vprofiledb
            ports:
              - "3306:3306"
            volumes:
              - vprofiledbdata:/var/lib/mysql
            environment:
              - MYSQL_ROOT_PASSWORD=vprodbpass
        vprocache01:
            image: memcached
            container_name: vprofilecache01
            ports:
              - "11211:11211"
        vpromq01:
            image: rabbitmq
            container_name: vprofilemq01
            ports:
              - "5672:5672"
            environment:
              - RABBITMQ_DEFAULT_USER=guest
              - RABBITMQ_DEFAULT_PASS=guest
        vproapp:
            image: jemdevops/vprofileapp:latest
            container_name: vprofileapp
            depends_on:
              - vprodb
              - vprocache01
              - vpromq01
            ports:
              - "8080:8080"
            volumes:
              - vprofileappdata:/usr/local/tomcat/webapps
        vproweb:
            image: jemdevops/vprofileweb:latest
            container_name: vprofileweb
            depends_on:
              - vproapp
            ports:
              - "80:80"
    volumes:
        vprofiledbdata: {}
        vprofileappdata: {}
  COMPOSE
}

resource "aws_instance" "vprofile_docker" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.vprofile.key_name
  subnet_id                   = local.resolved_subnet_id
  vpc_security_group_ids      = [aws_security_group.vprofile_docker.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-${var.environment}-root-vol"
    }
  }

  # ------------------------------------------------------------------
  # User-data bootstrap
  # ------------------------------------------------------------------
  # Runs once on first boot:
  #   1. System update
  #   2. Install Docker Engine + Docker Compose plugin (official repo)
  #   3. Write docker-compose.yml
  #   4. Pull images and start the stack
  #   5. Enable restart policy so the stack survives reboots
  # ------------------------------------------------------------------
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > /var/log/vprofile-init.log 2>&1

    # ── 1. System update ──────────────────────────────────────────────
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get upgrade -y

    # ── 2. Install Docker Engine ──────────────────────────────────────
    apt-get install -y ca-certificates curl gnupg lsb-release

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io \
                       docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    # Add ubuntu user to docker group (no sudo needed after re-login)
    usermod -aG docker ubuntu

    # ── 3. Write docker-compose.yml ───────────────────────────────────
    mkdir -p /opt/vprofile
    cat > /opt/vprofile/docker-compose.yml << 'COMPOSE'
    ${local.docker_compose_content}
    COMPOSE

    # ── 4. Pull images and start the stack ───────────────────────────
    cd /opt/vprofile
    docker compose pull
    docker compose up -d

    # ── 5. Systemd service for auto-restart on reboot ─────────────────
    cat > /etc/systemd/system/vprofile.service << 'SERVICE'
    [Unit]
    Description=vprofile Docker Compose stack
    Requires=docker.service
    After=docker.service network-online.target
    Wants=network-online.target

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    WorkingDirectory=/opt/vprofile
    ExecStart=/usr/bin/docker compose up -d --remove-orphans
    ExecStop=/usr/bin/docker compose down
    TimeoutStartSec=300

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable vprofile.service

    echo "=== vprofile bootstrap complete ==="
  EOF
  )

  tags = {
    Name = "${var.project_name}-${var.environment}-docker-host"
  }

  # Replace the instance if user_data changes (re-provisioning)
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Elastic IP – keeps the public IP stable across stop/start cycles
# ---------------------------------------------------------------------------

resource "aws_eip" "vprofile" {
  instance = aws_instance.vprofile_docker.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }
}
