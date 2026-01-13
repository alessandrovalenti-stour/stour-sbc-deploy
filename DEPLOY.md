# Deployment Script Usage

The `deploy.sh` script is the central entry point for managing the Stour LibreSBC AWS infrastructure. It handles both Terraform infrastructure provisioning and Ansible configuration.

## Prerequisites

*   **Terraform** (>= 1.5.0)
*   **Ansible** (>= 2.9)
*   **AWS CLI** configured with appropriate credentials
*   **SSH Key** for accessing instances (referenced in Terraform variables)

## Basic Usage

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
*   **Safety**: This will prompt for confirmation (`Are you sure? (y/N)`) before proceeding.
*   **Note**: This skips the Ansible stage automatically.

## Advanced Usage: Stages

You can limit execution to specific stages using the `--stage` flag.

### Run Only Infrastructure
Useful if you only want to update AWS resources (e.g., Security Groups, EC2 instance types) without re-running Ansible.

```bash
./deploy.sh --apply --stage infra
```

### Run Only Ansible
Useful for re-configuring software on existing instances (e.g., updating configuration files, restarting services) without checking Terraform state.

```bash
./deploy.sh --apply --stage ansible
```

## Options Reference

| Flag | Description |
| :--- | :--- |
| `--apply` | Creates or updates resources/configuration. |
| `--destroy` | Destroys AWS infrastructure. |
| `--stage <name>` | Selects the stage to run. Options: `infra`, `ansible`, `all` (default). |
| `--help` | Shows the help message. |

## Environment Variables

The script respects the following environment variables:

*   `AWS_REGION`: Defaults to `eu-west-2` (London).
*   `AWS_PROFILE`: Optional, if you use named profiles.

## Workflow Example

1.  **Initial Deployment**:
    ```bash
    ./deploy.sh --apply
    ```
2.  **Update Configuration** (after editing Ansible playbooks):
    ```bash
    ./deploy.sh --apply --stage ansible
    ```
3.  **Teardown**:
    ```bash
    ./deploy.sh --destroy
    ```

## Accessing LibreUI

LibreUI is configured to listen only on `localhost` (127.0.0.1) for security reasons. To access the web interface, you must establish an SSH tunnel.

**Command:**
```bash
ssh -i ~/.ssh/stour-sbc-key.pem admin@<SBC_IP> -L 8088:localhost:8088
```

*   Replace `<SBC_IP>` with the public IP of `sbc_a` or `sbc_b`.
*   Replace `~/.ssh/stour-sbc-key.pem` with the path to your actual private key.

Once the tunnel is established, open your browser and navigate to:
`http://localhost:8088`
