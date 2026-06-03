# StackNova — Environnement de recette

Déploiement automatisé d'un environnement de recette pour l'équipe QA de StackNova : un conteneur Nginx provisionné par **Terraform** et configuré par **Ansible**, le tout orchestré par un script unique.

Une seule commande suffit :

```bash
bash scripts/deploy.sh
```

---

## Architecture
┌──────────────┐    provisionne    ┌─────────────────────┐    configure    ┌──────────────┐
│  Terraform   │ ────────────────► │  Conteneur Docker   │ ◄────────────── │   Ansible    │
│  (provider   │                   │  stacknova-recette  │                 │  (connexion  │
│  kreuzwerker)│                   │  nginx:1.25.3 :8080 │                 │   docker)    │
└──────────────┘                   └─────────────────────┘                 └──────────────┘
- **Terraform** crée l'image et le conteneur, expose le port 8080, applique les labels `env=recette` et `project=stacknova`.
- **Ansible** se connecte au conteneur via `community.docker.docker` (mode `raw`, sans Python sur la cible) et personnalise la page d'accueil avec un horodatage dynamique.
- **`deploy.sh`** enchaîne les deux étapes et s'interrompt automatiquement à la moindre erreur.

---

## Prérequis

| Outil     | Version testée | Commande de vérification |
| --------- | -------------- | ------------------------ |
| Docker    | 29.5.2         | `docker --version`       |
| Terraform | 1.15.5         | `terraform --version`    |
| Ansible   | core 2.19.4    | `ansible --version`      |

Collection Ansible requise :

```bash
ansible-galaxy collection install community.docker
```

Environnement testé : Debian sous WSL2 avec Docker Desktop (intégration WSL activée).

---

## Arborescence

stacknova-infra/
├── terraform/
│   ├── providers.tf      # Provider Docker Kreuzwerker (version épinglée)
│   ├── main.tf           # Image + conteneur Nginx + labels
│   └── outputs.tf        # Nom du conteneur et port exposé
├── ansible/
│   ├── inventory.ini     # Cible : conteneur via connexion docker
│   └── playbook.yml      # Personnalisation index.html + check Nginx
├── scripts/
│   └── deploy.sh         # Orchestration terraform + ansible
├── screens/              # Captures d'écran de validation
└── README.md
---

## Utilisation

### Déploiement complet

```bash
bash scripts/deploy.sh
```

Accès : http://localhost:8080

### Destruction de l'environnement

```bash
terraform -chdir=terraform destroy -auto-approve
```

---

## Reproductibilité

Le déploiement est **idempotent et reproductible** :

1. Toutes les versions sont épinglées : provider Terraform (`kreuzwerker/docker 3.0.2`), image Docker (`nginx:1.25.3`). Aucun usage de `:latest`.
2. Le script `deploy.sh` orchestre l'intégralité du flux et s'interrompt sur toute erreur (`set -euo pipefail`).
3. Aucune intervention manuelle n'est requise entre les étapes.

**Test effectué** :

```bash
terraform -chdir=terraform destroy -auto-approve   # destruction complète
bash scripts/deploy.sh                              # redéploiement
```

Résultat : l'environnement est reconstruit à l'identique, seul l'horodatage affiché sur la page change (preuve que le playbook Ansible est bien rejoué dynamiquement).

---

## Captures d'écran

Toutes les captures sont dans `screens/` :

- `01-terraform-apply.png` — sortie de `terraform apply` avec les outputs.
- `02-nginx-browser.png` — page Nginx par défaut après provisionnement.
- `03-ansible-playbook.png` — exécution du playbook.
- `04-page-personnalisee.png` — page personnalisée avec horodatage.
- `05-deploy-script.png` — exécution complète de `deploy.sh`.

---

## Questions théoriques

### Q1. Différence entre Terraform et Ansible — complémentarité dans ce projet

**Terraform** est un outil de *provisionnement* : il décrit et crée l'infrastructure (ici le conteneur Docker) de manière déclarative, en s'appuyant sur un state. **Ansible** est un outil de *configuration* : il agit sur des cibles existantes pour les amener dans un état donné (ici personnaliser le contenu Nginx). Dans ce projet, Terraform crée le conteneur, puis Ansible le configure — chacun fait ce qu'il fait le mieux.

### Q2. Rôle du state file Terraform et risques

Le state (`terraform.tfstate`) est la mémoire de Terraform : il associe les ressources déclarées dans le code aux ressources réellement créées sur l'infrastructure. Sans lui, Terraform serait incapable de savoir ce qui existe déjà, ce qu'il doit modifier ou détruire. En équipe, une mauvaise gestion (state local non partagé, écrasement concurrent, fuite de secrets stockés dans le state) provoque des dérives entre l'infra réelle et le code, voire la destruction accidentelle de ressources. Solution standard : un *remote backend* (S3, Terraform Cloud) avec verrouillage.

### Q3. Idempotence — exemple dans ce projet

L'idempotence est la propriété qu'une opération produise le même résultat qu'elle soit exécutée une ou plusieurs fois. Exemple concret : relancer `bash scripts/deploy.sh` sur un environnement déjà déployé ne crée pas un deuxième conteneur — Terraform constate que l'infra correspond déjà au code et ne fait rien, et Ansible réécrit `index.html` à l'identique (hors horodatage) sans casser l'existant.

### Q4. `terraform apply` vs `terraform apply -replace`

`terraform apply` applique uniquement les changements nécessaires pour faire converger l'infra vers le code. `terraform apply -replace=<ressource>` force la destruction puis la recréation d'une ressource spécifique, même si rien n'a changé dans le code. On l'utilise quand une ressource est dans un état dégradé invisible pour Terraform (conteneur corrompu, certificat à régénérer, drift manuel sur l'instance) — c'est l'équivalent moderne et ciblé de `terraform taint`.

### Q5. Pourquoi éviter le tag `:latest` en production

`:latest` est un pointeur mouvant : l'image qu'il référence change sans préavis quand l'éditeur publie une nouvelle version. Deux déploiements identiques à 24 h d'écart peuvent donc embarquer des images différentes, ce qui casse la reproductibilité, complique le debug (« ça marchait hier »), et expose à des régressions ou des changements de comportement non maîtrisés. En production on épingle une version explicite (`nginx:1.25.3`) pour garantir un déploiement déterministe.

---

## Auteur

Évaluation IaC — StackNova
Dépôt : https://github.com/iule-afk/stacknova-infra

