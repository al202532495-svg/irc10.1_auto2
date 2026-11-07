# Practica: microservicios con Flask, MongoDB, Docker y Kubernetes

Aplicacion de tareas con tres microservicios:

| Servicio | Responsabilidad | Base de datos |
|---|---|---|
| auth-service | Registro, login, emision de JWT | mongo-auth |
| tasks-service | CRUD de tareas (valida JWT por su cuenta) | mongo-tasks |
| dashboard-service | Estadisticas (consulta a tasks-service por HTTP) | ninguna |
| gateway (nginx) | Punto de entrada unico + frontend | - |

## Fase 1: Docker Compose

    cp .env.example .env
    docker compose up -d --build
    # abrir http://localhost:8080

## Fase 2: Kubernetes (minikube)

    minikube start
    eval $(minikube docker-env)          # Windows PowerShell: & minikube -p minikube docker-env --shell powershell | Invoke-Expression
    docker compose build                 # construye las imagenes dentro de minikube
    kubectl apply -f k8s/
    kubectl get pods -n microservicios -w
    minikube service gateway -n microservicios

