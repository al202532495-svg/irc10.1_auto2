#!/usr/bin/env bash
# =============================================================================
#  setup-rocky.sh — Prepara Rocky Linux 9.x para correr Floci (AWS/Azure/GCP/OCI)
#  Ejecutar como root o con sudo:   sudo bash setup-rocky.sh
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta este script con sudo o como root." >&2
  exit 1
fi

TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
echo ">> Usuario que usará Docker: ${TARGET_USER}"

# -----------------------------------------------------------------------------
# 1. Paquetes base
# -----------------------------------------------------------------------------
echo ">> [1/7] Actualizando sistema e instalando utilidades base..."
dnf -y update
dnf -y install dnf-plugins-core curl wget unzip tar git jq openssl \
               ca-certificates bash-completion

# -----------------------------------------------------------------------------
# 2. Quitar Podman/Buildah (Rocky los trae y chocan con containerd.io/runc)
# -----------------------------------------------------------------------------
echo ">> [2/7] Removiendo podman/buildah si existen (conflicto con Docker CE)..."
dnf -y remove podman buildah runc 2>/dev/null || true

# -----------------------------------------------------------------------------
# 3. Docker CE + Compose plugin
# -----------------------------------------------------------------------------
echo ">> [3/7] Instalando Docker CE..."
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io \
               docker-buildx-plugin docker-compose-plugin

# Rotación de logs para que los contenedores sidecar no llenen el disco
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "20m", "max-file": "3" },
  "default-ulimits": {
    "nofile": { "Name": "nofile", "Hard": 1048576, "Soft": 1048576 }
  }
}
EOF

systemctl enable --now docker
usermod -aG docker "${TARGET_USER}" || true

# -----------------------------------------------------------------------------
# 4. Ajustes de kernel (OpenSearch, k3s para EKS/AKS/GKE, Kafka/Redpanda)
# -----------------------------------------------------------------------------
echo ">> [4/7] Aplicando sysctl..."
cat > /etc/sysctl.d/99-floci.conf <<'EOF'
# OpenSearch necesita esto o no arranca
vm.max_map_count = 262144
# k3s / kubelet abren muchos watchers
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
# Redpanda (MSK / Managed Kafka / Event Hubs)
fs.aio-max-nr = 1048576
# Reenvío de paquetes para redes de Docker / k3s
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

# k3s dentro de Docker necesita estos módulos
modprobe br_netfilter || true
modprobe overlay || true
printf "br_netfilter\noverlay\n" > /etc/modules-load.d/floci.conf

# -----------------------------------------------------------------------------
# 5. Terraform (repo oficial de HashiCorp)
# -----------------------------------------------------------------------------
echo ">> [5/7] Instalando Terraform..."
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
dnf -y install terraform

# -----------------------------------------------------------------------------
# 6. CLIs de nube (opcionales pero útiles para la demo)
# -----------------------------------------------------------------------------
echo ">> [6/7] Instalando CLIs..."

# AWS CLI v2
if ! command -v aws >/dev/null 2>&1; then
  tmp=$(mktemp -d)
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "$tmp/awscliv2.zip"
  unzip -q "$tmp/awscliv2.zip" -d "$tmp"
  "$tmp/aws/install" --update
  rm -rf "$tmp"
fi

# Azure CLI
if ! command -v az >/dev/null 2>&1; then
  rpm --import https://packages.microsoft.com/keys/microsoft.asc
  dnf -y install https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm || true
  dnf -y install azure-cli || echo "   (azure-cli no se pudo instalar; es opcional)"
fi

# Google Cloud CLI
if ! command -v gcloud >/dev/null 2>&1; then
  cat > /etc/yum.repos.d/google-cloud-sdk.repo <<'EOF'
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
  dnf -y install google-cloud-cli || echo "   (gcloud no se pudo instalar; es opcional)"
fi

# OCI CLI (vía pip en un venv aislado)
if ! command -v oci >/dev/null 2>&1; then
  dnf -y install python3 python3-pip
  python3 -m venv /opt/oci-cli
  /opt/oci-cli/bin/pip install -q --upgrade pip oci-cli || echo "   (oci-cli es opcional)"
  ln -sf /opt/oci-cli/bin/oci /usr/local/bin/oci || true
fi

# floci-cli (opcional; el compose no lo necesita)
su - "${TARGET_USER}" -c 'curl -fsSL https://floci.io/install.sh | sh' || \
  echo "   (floci-cli es opcional; puedes instalarlo después)"

# -----------------------------------------------------------------------------
# 7. Firewall (solo si quieres acceder desde otra máquina)
# -----------------------------------------------------------------------------
echo ">> [7/7] Firewall: no se abren puertos por defecto."
echo "   Por defecto el laboratorio solo escucha en 127.0.0.1 (ver .env)."
echo "   Para acceder desde tu laptop usa un túnel SSH (ver README.md)."

echo
echo "======================================================================"
echo " Listo. Cierra sesión y vuelve a entrar (o ejecuta 'newgrp docker')"
echo " para usar Docker sin sudo. Después:   ./start.sh"
echo "======================================================================"
docker --version
docker compose version
terraform version | head -n1
