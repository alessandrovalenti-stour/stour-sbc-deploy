# Stour LibreSBC on AWS – History

Chronological overview of the main changes made to this project.

## Phase 1 – Initial Terraform & Ansible skeleton

- Introduced base Terraform configuration:
  - Provider and version constraints.
  - Security group for SBC traffic (SIP, RTP, SSH).
  - Data source for Debian 12 AMI.
- Added two EC2 instances:
  - `sbc_a` and `sbc_b` running Debian 12 in existing public subnets.
- Generated an Ansible inventory (`inventory.ini`) from Terraform outputs.
- Created initial Ansible structure:
  - `site.yml` with bootstrap, HA, and LibreSBC playbooks.
  - `bootstrap` role to install basic system packages and AWS CLI.

## Phase 2 – LibreSBC installer integration and fixes

- Added `libresbc_packages_runner` role to wrap the upstream LibreSBC Ansible playbooks.
- Cloned the LibreSBC Git repository into `/opt/libresbc` on each SBC.
- Installed required Ansible collections (e.g. `community.docker`).
- Fixed upstream issues in the LibreSBC Ansible roles:
  - Quoted Jinja2 default filter in `platform/tasks/debian.yml` (`default('UTC')`).
  - Quoted hostname change message in `platform/tasks/debian.yml`.
  - Ensured the Docker directory exists before provisioning `docker-compose.yml` in `libresbc-container`.
- Wired the wrapper playbook to call upstream `deployment.yml` with the correct tags and extra vars:
  - `platform,docker,libresbc-container,libreui`.
  - `nodeid` derived from Ansible inventory hostname, with underscores replaced by dashes.
  - Database and JWT settings for LibreUI.
  - Redis configuration and source directory parameters (`with_source`, `srcdir`).

## Phase 3 – Docker, FreeSWITCH CLI and runtime improvements

- Ensured Docker and prerequisites are installed via the `bootstrap` and `libresbc_packages_runner` roles.
- Created a host-level `fs_cli` wrapper script:
  - Executes `fs_cli` inside the `switch` container.
  - Handles both interactive and non-interactive modes.
  - Uses the `LIBRESBC` password when connecting.
- Cleaned up issues that prevented containers from starting correctly:
  - Removed invalid `fsw.xml` directory that blocked container startup.
  - Fixed Redis and environment file provisioning for the LibreSBC containers.

## Phase 4 – LibreUI access model and SSH tunnelling

- Initially exposed LibreUI (port `8088`) via the SBC security group to test connectivity.
- Then tightened exposure by removing the public ingress rule for `8088` from the Terraform security group.
- Updated LibreSBC systemd unit for LibreUI to listen on loopback / restricted interfaces.
- Documented SSH tunnel access for LibreUI so that operators can connect from their laptops via SSH:
  - Example: `ssh -i ~/.ssh/stour-sbc-key.pem admin@<SBC_IP> -L 8088:localhost:8088` (earlier model).

## Phase 5 – Repository hygiene and documentation

- Initialized the Git repository for this project and added a `.gitignore`:
  - Ignored Terraform state, lock files, and overrides.
  - Ignored Ansible retry files and generated `inventory.ini`.
  - Ignored local IDE and OS-specific files.
- Created the first version of `README.md` describing:
  - Project purpose and architecture.
  - Basic deployment flow with `deploy.sh`.
  - How to access LibreSBC and manage containers.
- Added detailed deployment instructions in `DEPLOY.md` (later merged into `README.md`). 

## Phase 6 – Controller instance for internal WebGUI

- Extended Terraform to provision a third EC2 instance:
  - `controller` (Debian 12) dedicated to hosting a FastAPI-based management WebGUI.
- Added a dedicated security group for the controller:
  - SSH access from the admin CIDR.
  - HTTP/HTTPS and FastAPI port (e.g. 8000) restricted to admin CIDR.
- Updated the SBC security group to allow all traffic originating from the controller security group.
- Extended the generated `inventory.ini` with a `[controller]` group and SSH settings.
- Exposed controller public and private IPs as Terraform outputs.

## Phase 7 – Binding LibreUI to AWS private IPs

- Changed the LibreUI binding model so that each SBC binds LibreUI on port `8088` to its **AWS private IP**:
  - Patched `libreui.service` in the LibreSBC Ansible role from `-H 0.0.0.0` (or `127.0.0.1`) to `-H {{ private_ip }}`.
  - `private_ip` is supplied from the Terraform-generated Ansible inventory.
- Verified on both SBC nodes that `libreui` listens only on the respective private IPs:
  - `10.5.22.178:8088` for `sbc_a`.
  - `10.5.38.165:8088` for `sbc_b`.
- Updated documentation to show the recommended access pattern:
  - From the controller directly to the SBC private IPs.
  - From an operator laptop via SSH tunnel through the controller:
    - `ssh -i ~/.ssh/stour-sbc-key.pem admin@<CONTROLLER_PUBLIC_IP> -L 8088:<SBC_PRIVATE_IP>:8088`.

## Phase 8 – Documentation consolidation

- Updated `README.md` to include:
  - Full architecture overview, including the controller instance.
  - Detailed usage of `deploy.sh`, including stages and options.
  - SSH access examples and LibreUI access patterns.
- Merged the previous `DEPLOY.md` content into `README.md` so that:
  - `README.md` is the single source of truth for usage and deployment.
  - `DEPLOY.md` was removed from the repository.

