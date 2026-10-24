#!/usr/bin/env bash
# stop.sh — Detiene el laboratorio.
#   ./stop.sh          detiene los emuladores (el estado se conserva si STORAGE_MODE=hybrid)
#   ./stop.sh --reset  además borra todo el estado y los contenedores sidecar
set -euo pipefail
cd "$(dirname "$0")"

docker compose down

# Los emuladores crean contenedores "hermanos" (Lambda, RDS, k3s, Postgres...).
# Se etiquetan/nombran con prefijo floci; los limpiamos para liberar RAM.
sidecars=$(docker ps -aq --filter "name=floci" || true)
if [[ -n "$sidecars" ]]; then
  echo ">> Eliminando contenedores sidecar restantes..."
  docker rm -f $sidecars >/dev/null
fi

if [[ "${1:-}" == "--reset" ]]; then
  echo ">> Borrando estado persistido (data/*) y estado de Terraform..."
  sudo rm -rf data/aws data/azure data/gcp data/oci
  find terraform -name 'terraform.tfstate*' -delete
  find terraform -name '.terraform' -type d -prune -exec rm -rf {} +
  find terraform -name '.terraform.lock.hcl' -delete
  echo "   ✓ Nube limpia. ./start.sh para empezar de cero."
fi
