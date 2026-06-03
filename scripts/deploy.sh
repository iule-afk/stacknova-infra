#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}=== [1/3] Initialisation Terraform ===${NC}"
terraform -chdir=terraform init -input=false

echo -e "${BLUE}=== [2/3] Provisionnement de l'infrastructure ===${NC}"
terraform -chdir=terraform apply -auto-approve

echo -e "${BLUE}=== [3/3] Configuration via Ansible ===${NC}"
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

echo -e "${GREEN}=== Déploiement terminé avec succès ===${NC}"
echo -e "Accès : http://localhost:8080"
