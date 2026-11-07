"""
dashboard-service: calcula estadisticas de las tareas del usuario.
NO tiene base de datos: obtiene los datos llamando al tasks-service por HTTP
(comunicacion entre servicios). Si tasks-service cae, responde con un error
controlado en lugar de romperse.
"""
import os
import socket
from collections import Counter

import jwt
import requests
from flask import Flask, jsonify, request

app = Flask(__name__)

TASKS_URL = os.getenv("TASKS_URL", "http://tasks-service:5000")
JWT_SECRET = os.getenv("JWT_SECRET", "cambia-este-secreto")
VERSION = os.getenv("APP_VERSION", "1.0")


def info():
    return {"servicio": "dashboard-service", "version": VERSION, "atendido_por": socket.gethostname()}


@app.get("/health")
def health():
    return jsonify(status="ok", **info())


@app.get("/api/dashboard/stats")
def stats():
    cabecera = request.headers.get("Authorization", "")
    try:
        usuario = jwt.decode(cabecera.removeprefix("Bearer "), JWT_SECRET, algorithms=["HS256"])["sub"]
    except jwt.InvalidTokenError:
        return jsonify(error="token invalido o ausente", **info()), 401

    # Llamada servicio -> servicio. Reenviamos el mismo token del usuario.
    try:
        r = requests.get(f"{TASKS_URL}/api/tasks", headers={"Authorization": cabecera}, timeout=3)
        r.raise_for_status()
        datos = r.json()
    except requests.RequestException:
        return jsonify(error="el servicio de tareas no esta disponible, intenta mas tarde",
                       **info()), 503

    lista = datos["tareas"]
    completadas = sum(1 for t in lista if t["completada"])
    por_dia = Counter(t["creada"][:10] for t in lista)

    return jsonify(
        usuario=usuario,
        total=len(lista),
        completadas=completadas,
        pendientes=len(lista) - completadas,
        creadas_por_dia=dict(sorted(por_dia.items())),
        tareas_atendido_por=datos.get("atendido_por"),
        **info(),
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
