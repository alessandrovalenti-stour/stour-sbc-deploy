#!/bin/bash
set -euo pipefail

# Default values
MODE="none"
STAGE="all"
AWS_REGION="${AWS_REGION:-eu-west-2}"
export AWS_PROFILE="${AWS_PROFILE:-stour}"
INVENTORY_REL="../inventory.ini"

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --apply           Apply infrastructure changes"
    echo "  --destroy         Destroy infrastructure"
    echo "  --stage STAGE     Select stage to run: 'infra', 'ansible', or 'all' (default: all)"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --apply"
    echo "  $0 --apply --stage infra"
    echo "  $0 --apply --stage ansible"
    echo "  $0 --destroy"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)
            MODE="apply"
            shift
            ;;
        --destroy)
            MODE="destroy"
            shift
            ;;
        --stage)
            STAGE="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown argument $1"
            usage
            ;;
    esac
done

# Validate Mode
if [[ "$MODE" == "none" ]]; then
    echo "Error: You must specify either --apply or --destroy"
    usage
fi

# Validate Stage
if [[ ! "$STAGE" =~ ^(infra|ansible|all)$ ]]; then
    echo "Error: Stage must be one of: infra, ansible, all"
    exit 1
fi

# Safety check for destroy
if [[ "$MODE" == "destroy" ]]; then
    if [[ "$STAGE" == "ansible" ]]; then
        echo "Error: --destroy cannot be used with --stage ansible"
        exit 1
    fi
    echo "WARNING: You are about to DESTROY the infrastructure."
    read -p "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# ---- INFRASTRUCTURE STAGE ----
run_infra() {
    echo "==> [INFRA] Initializing Terraform..."
    terraform init

    if [[ "$MODE" == "apply" ]]; then
        echo "==> [INFRA] Applying changes..."
        terraform apply -auto-approve
    elif [[ "$MODE" == "destroy" ]]; then
        echo "==> [INFRA] Destroying infrastructure..."
        terraform destroy -auto-approve
    fi
}

# ---- ANSIBLE STAGE ----
run_ansible() {
    if [[ "$MODE" == "destroy" ]]; then
        echo "Skipping Ansible stage for destroy mode."
        return
    fi

    echo "==> [ANSIBLE] Gathering Terraform outputs..."
    # Ensure we are in the root directory for terraform output
    if ! VIP_ALLOCATION_ID=$(terraform output -raw vip_allocation_id); then
        echo "Error: Failed to get vip_allocation_id from Terraform"
        exit 1
    fi
    
    echo "    VIP Allocation ID: $VIP_ALLOCATION_ID"

    echo "==> [ANSIBLE] Running Playbooks..."
    cd ansible
    
    # Check if inventory file exists
    if [[ ! -f "$INVENTORY_REL" ]]; then
        echo "Error: Inventory file $INVENTORY_REL not found. Did infrastructure deployment succeed?"
        exit 1
    fi

    ansible-playbook -i "$INVENTORY_REL" site.yml \
        -e "vip_allocation_id=$VIP_ALLOCATION_ID" \
        -e "aws_region=$AWS_REGION"
    
    cd ..
}

# Execute Stages
if [[ "$STAGE" == "all" || "$STAGE" == "infra" ]]; then
    run_infra
fi

if [[ "$STAGE" == "all" || "$STAGE" == "ansible" ]]; then
    run_ansible
fi

echo "==> Done."
