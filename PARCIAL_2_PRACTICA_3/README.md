# Laboratorio multinube con Floci (Rocky Linux 9)

AWS, Azure, GCP y Oracle Cloud emulados en una sola VM, listos para
`terraform plan / apply / destroy` sin cuentas reales ni costos.

| Nube  | Emulador    | Puerto | Terraform provider   |
|-------|-------------|--------|----------------------|
| AWS   | `floci`     | 4566   | `hashicorp/aws`      |
| Azure | `floci-az`  | 4577   | `hashicorp/azurerm`  |
| GCP   | `floci-gcp` | 4588   | `hashicorp/google`   |
| OCI   | `floci-oci` | 4599   | `oracle/oci`         |

Tu VM (8 vCPU, 16 GB RAM, 100 GB disco) alcanza para las cuatro nubes a la vez,
incluyendo servicios pesados (RDS/Cloud SQL, Lambda, un clúster k3s de EKS/AKS/GKE).

## Estructura

```
floci-lab/
├── setup-rocky.sh        # instala Docker, Terraform, CLIs y ajustes de kernel
├── docker-compose.yml    # las 4 nubes
├── .env                  # interfaz de escucha, versiones y modo de almacenamiento
├── start.sh              # levanta, espera, confía el cert de Azure, crea llave OCI
├── stop.sh               # detiene (--reset borra todo el estado)
├── floci-env.sh          # variables para aws / az / gcloud / oci / terraform
└── terraform/
    ├── aws/   azure/   gcp/   oci/     # una demo por nube
```

## 1. Preparar la VM (una sola vez)

```bash
scp -r floci-lab usuario@IP_DE_LA_VM:~        # o súbelo como prefieras
ssh usuario@IP_DE_LA_VM
cd ~/floci-lab
chmod +x *.sh
sudo ./setup-rocky.sh
newgrp docker          # o cierra sesión y vuelve a entrar
```

El script quita Podman (choca con Docker CE en Rocky), instala Docker CE + Compose,
Terraform, AWS CLI, Azure CLI, gcloud y OCI CLI, y ajusta `vm.max_map_count`
(OpenSearch) e `inotify` (k3s).

## 2. Levantar las nubes

```bash
./start.sh
source ./floci-env.sh
```

La primera vez tarda unos minutos mientras descarga imágenes.

## 3. Probar con las CLIs

```bash
aws s3 ls
aws sqs list-queues
az storage container list                     # usa AZURE_STORAGE_CONNECTION_STRING
gcloud storage buckets list
ocil os ns get
```

## 4. Terraform, nube por nube

```bash
cd terraform/aws   && terraform init && terraform apply -auto-approve && cd -
cd terraform/azure && terraform init && terraform apply -auto-approve && cd -
cd terraform/gcp   && terraform init && terraform apply -auto-approve && cd -
cd terraform/oci   && terraform init && terraform apply -auto-approve && cd -
```

Después de un `apply`, corre `terraform plan` otra vez: debe decir "No changes".
Es buen momento para explicar estado y drift. Al final, `terraform destroy`.

Siempre ejecuta Terraform en una terminal donde hayas hecho `source ./floci-env.sh`
(GCP necesita `GOOGLE_OAUTH_ACCESS_TOKEN` y OCI `TF_VAR_CLIENT_HOST_OVERRIDES`).

## 5. Ver los recursos

Consola web de AWS: `http://127.0.0.1:4566/_floci/ui` (abre en `:4500`).

Por defecto todo escucha solo en `127.0.0.1`. Para verlo desde tu laptop, abre un túnel:

```bash
ssh -L 4566:localhost:4566 -L 4500:localhost:4500 \
    -L 4577:localhost:4577 -L 4588:localhost:4588 -L 4599:localhost:4599 \
    usuario@IP_DE_LA_VM
```

y abre `http://localhost:4566/_floci/ui` en tu navegador.

Si prefieres exponerlo en la red, cambia `BIND_ADDR=0.0.0.0` en `.env` y reinicia.
Ojo: Floci no tiene autenticación y controla el Docker del host, así que hazlo
solo en una red de laboratorio aislada. Docker publica los puertos por encima de
firewalld, así que el firewall de Rocky no los protege.

## Operación

| Acción | Comando |
|---|---|
| Ver estado | `docker compose ps` |
| Logs de una nube | `docker compose logs -f floci-az` |
| Uso de RAM/CPU | `docker stats` |
| Detener (conserva estado) | `./stop.sh` |
| Nube limpia para otra demo | `./stop.sh --reset && ./start.sh` |
| Fijar versiones | edita `FLOCI_*_TAG` en `.env` |

Para demos repetibles pon `STORAGE_MODE=memory` en `.env`: cada reinicio deja todo vacío.

## Problemas comunes

**Azure: `server gave HTTP response to HTTPS client`** → falta TLS. Revisa que
`FLOCI_AZ_TLS_ENABLED: "true"` esté en el compose y vuelve a correr `./start.sh`.

**Azure: `x509: certificate signed by unknown authority`** → el certificado no está
confiado. `./start.sh` lo instala en `/etc/pki/ca-trust/source/anchors/`. Si
recreaste el contenedor y borraste `data/azure`, el cert cambió: corre `./start.sh` otra vez.

**Azure 4.x se queja de `skip_provider_registration`** → cámbialo por
`resource_provider_registrations = "none"`.

**GCP: error de credenciales** → no hiciste `source ./floci-env.sh`
(falta `GOOGLE_OAUTH_ACCESS_TOKEN`).

**GCP: no puedo crear Pub/Sub o Firestore con Terraform** → esos servicios solo
hablan gRPC en floci-gcp; créalos con `gcloud` o un SDK.

**AWS: un recurso nuevo intenta ir a AWS real** → agrega ese servicio al bloque
`endpoints {}` del provider.

**Permiso denegado sobre `/var/run/docker.sock`** → SELinux. El compose ya trae
`label:disable`; si persiste, revisa `sudo ausearch -m avc -ts recent`.

**Se acaba la RAM** → `docker stats`. Los sidecars (k3s, Postgres, OpenSearch) son
los que consumen; `./stop.sh` los limpia.

## Límites del emulador

Es una nube emulada, no una real. Sirve muy bien para enseñar el flujo de Terraform,
la forma de los recursos y cómo se relacionan en cada nube. No valida permisos IAM
reales, cuotas, latencias, redes físicas ni costos, y algunos servicios son stubs.
