# Stour LibreSBC on AWS

This project automates the deployment of a High Availability (HA) capable **LibreSBC** cluster on AWS using **Terraform** and **Ansible**.

It provisions EC2 instances, configures networking/security, and deploys the LibreSBC software stack (FreeSWITCH, Kamailio/LibreUI, Redis) in Docker containers.

## Architecture

*   **Infrastructure (Terraform)**:
    *   Deploys 2 EC2 instances (`sbc-a` and `sbc-b`) in an existing VPC.
    *   Deploys 1 EC2 instance `controller` (Debian 12) per la WebGUI FastAPI.
    *   Configures Security Groups for SIP, RTP, Management e accesso dal controller.
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
*   **AWS CLI** configured with appropriate credentials
*   **SSH Key Pair**: you must have the `stour-sbc-key.pem` (or configured key) available locally.

## Deployment (deploy.sh)

The `deploy.sh` script is the central entry point for managing the Stour LibreSBC AWS infrastructure. It handles both Terraform infrastructure provisioning and Ansible configuration.

### Basic Usage

The script requires an operation mode flag (`--apply` or `--destroy`).

```bash
./deploy.sh [OPTIONS]
```

### 1. Deploy Everything (Default)

To provision infrastructure and configure it immediately:

```bash
./deploy.sh --apply
```

This runs the `infra` stage followed by the `ansible` stage.

### 2. Destroy Infrastructure

To tear down all resources created by Terraform:

```bash
./deploy.sh --destroy
```

*   Safety: this will prompt for confirmation (`Are you sure? (y/N)`) before proceeding.
*   Note: this skips the Ansible stage automatically.

### Advanced Usage: Stages

You can limit execution to specific stages using the `--stage` flag.

#### Run Only Infrastructure

Useful if you only want to update AWS resources (e.g., Security Groups, EC2 instance types) without re-running Ansible.

```bash
./deploy.sh --apply --stage infra
```

#### Run Only Ansible

Useful for re-configuring software on existing instances (e.g., updating configuration files, restarting services) without checking Terraform state.

```bash
./deploy.sh --apply --stage ansible
```

### Options Reference

| Flag | Description |
| :--- | :--- |
| `--apply` | Creates or updates resources/configuration. |
| `--destroy` | Destroys AWS infrastructure. |
| `--stage <name>` | Selects the stage to run. Options: `infra`, `ansible`, `all` (default). |
| `--help` | Shows the help message. |

### Environment Variables

The script respects the following environment variables:

*   `AWS_REGION`: defaults to `eu-west-2` (London).
*   `AWS_PROFILE`: optional, if you use named profiles.

### Workflow Example

1.  Initial deployment:

    ```bash
    ./deploy.sh --apply
    ```

2.  Update configuration (after editing Ansible playbooks):

    ```bash
    ./deploy.sh --apply --stage ansible
    ```

3.  Teardown:

    ```bash
    ./deploy.sh --destroy
    ```

## Accessing the System

### SSH Access
Connect to the instances using the `admin` user:

```bash
ssh -i ~/.ssh/stour-sbc-key.pem admin@<SBC_IP>
```

### LibreSBC Web UI
Each SBC exposes LibreUI on port `8088`, bound to its **AWS private IP** (for example `10.5.22.178` or `10.5.38.165`).  
Typical access is via the `controller` instance inside the VPC.

From your laptop you can create an SSH tunnel via the controller that forwards `8088` to the private IP of an SBC:

```bash
ssh -i ~/.ssh/stour-sbc-key.pem admin@<CONTROLLER_PUBLIC_IP> -L 8088:<SBC_PRIVATE_IP>:8088
```

Then open your browser at:
[http://localhost:8088](http://localhost:8088)

Replace:
* `<CONTROLLER_PUBLIC_IP>` with the public IP of the `controller` instance.
* `<SBC_PRIVATE_IP>` with the private IP of `sbc_a` or `sbc_b`.

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
