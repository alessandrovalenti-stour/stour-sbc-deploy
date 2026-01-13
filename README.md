# Stour LibreSBC on AWS

This project automates the deployment of a High Availability (HA) capable **LibreSBC** cluster on AWS using **Terraform** and **Ansible**.

It provisions EC2 instances, configures networking/security, and deploys the LibreSBC software stack (FreeSWITCH, Kamailio/LibreUI, Redis) in Docker containers.

## Architecture

*   **Infrastructure (Terraform)**:
    *   Deploys 2 EC2 instances (`sbc-a` and `sbc-b`) in an existing VPC.
    *   Configures Security Groups for SIP, RTP, and Management.
    *   Prepares IAM roles for potential EIP failover.
*   **Configuration (Ansible)**:
    *   Bootstraps the OS (Debian/Ubuntu) with Docker and dependencies.
    *   Deploys LibreSBC components using Docker Compose.
    *   **Components**:
        *   `switch`: FreeSWITCH (Media/Signaling)
        *   `liberator`: API/Controller
        *   `rdb`: Redis Database
        *   `libreui`: Web User Interface

## Prerequisites

*   **Terraform** (>= 1.5.0)
*   **Ansible** (>= 2.9)
*   **AWS CLI** (Configured with credentials)
*   **SSH Key Pair**: You must have the `stour-sbc-key.pem` (or configured key) available locally.

## Getting Started

### 1. Deployment

The project includes a helper script `deploy.sh` to manage the lifecycle.

```bash
# Deploy Infrastructure and Configure Software
./deploy.sh --apply
```

For more details on deployment options, see [DEPLOY.md](DEPLOY.md).

### 2. Accessing the System

#### SSH Access
Connect to the instances using the `admin` user:

```bash
ssh -i ~/.ssh/stour-sbc-key.pem admin@<SBC_IP>
```

#### LibreSBC Web UI
For security, the LibreUI web interface (port 8088) is bound to `localhost` on the servers. To access it, establish an SSH tunnel:

```bash
ssh -i ~/.ssh/stour-sbc-key.pem admin@<SBC_IP> -L 8088:localhost:8088
```

Then open your browser at:
[http://localhost:8088](http://localhost:8088)

## Management

### Docker Containers
Check the status of LibreSBC containers:
```bash
sudo docker ps
```

### FreeSWITCH CLI
A wrapper script is installed to easily access the FreeSWITCH CLI:
```bash
fs_cli
```

## Directory Structure

*   `main.tf`, `variables.tf`: Terraform infrastructure definitions.
*   `ansible/`: Ansible playbooks and roles.
    *   `roles/libresbc_packages_runner`: Main installer wrapper.
*   `deploy.sh`: Orchestration script.
