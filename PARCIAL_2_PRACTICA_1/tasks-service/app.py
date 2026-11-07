"""
tasks-service: CRUD de tareas por usuario.
Valida el JWT por su cuenta (solo necesita el secreto compartido); NUNCA llama al auth-service.
Tiene su propia base de datos (mongo-tasks).
"""
import os
import socket
import datetime
from functools import wraps

import jwt
from bson import ObjectId
from bson.errors import InvalidId
from flask import Flask, jsonify, request, g
from pymongo import MongoClient, errors

app = Flask(__name__)

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/tasksdb")
JWT_SECRET = os.getenv("JWT_SECRET", "cambia-este-secreto")
VERSION = os.getenv("APP_VERSION", "1.0")

client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=3000)
db = client.get_default_database()
tareas = db["tareas"]


def info():
    return {"servicio": "tasks-service", "version": VERSION, "atendido_por": socket.gethostname()}


def requiere_token(f):
    """Decorador: verifica la firma y expiracion del JWT sin consultar a nadie."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        cabecera = request.headers.get("Authorization", "")
        if not cabecera.startswith("Bearer "):
            return jsonify(error="falta el token", **info()), 401
        try:
            payload = jwt.decode(cabecera[7:], JWT_SECRET, algorithms=["HS256"])
        except jwt.ExpiredSignatureError:
            return jsonify(error="token expirado", **info()), 401
        except jwt.InvalidTokenError:
            return jsonify(error="token invalido", **info()), 401
        g.usuario = payload["sub"]
        return f(*args, **kwargs)
    return wrapper


def a_json(t):
    return {"id": str(t["_id"]), "titulo": t["titulo"], "completada": t["completada"],
            "creada": t["creada"].isoformat()}


def buscar_id(tarea_id):
    try:
        return ObjectId(tarea_id)
    except InvalidId:
        return None


@app.get("/health")
def health():
    try:
        client.admin.command("ping")
        return jsonify(status="ok", **info())
    except errors.PyMongoError:
        return jsonify(status="sin base de datos", **info()), 503


@app.get("/api/tasks")
@requiere_token
def listar():
    lista = [a_json(t) for t in tareas.find({"usuario": g.usuario}).sort("creada", -1)]
    return jsonify(tareas=lista, **info())


@app.post("/api/tasks")
@requiere_token
def crear():
    titulo = ((request.get_json(silent=True) or {}).get("titulo") or "").strip()
    if not titulo:
        return jsonify(error="el titulo es obligatorio", **info()), 400
    doc = {"usuario": g.usuario, "titulo": titulo, "completada": False,
           "creada": datetime.datetime.now(datetime.timezone.utc)}
    doc["_id"] = tareas.insert_one(doc).inserted_id
    return jsonify(tarea=a_json(doc), **info()), 201


@app.put("/api/tasks/<tarea_id>")
@requiere_token
def actualizar(tarea_id):
    oid = buscar_id(tarea_id)
    datos = request.get_json(silent=True) or {}
    cambios = {k: datos[k] for k in ("titulo", "completada") if k in datos}
    if oid is None or not cambios:
        return jsonify(error="id o datos invalidos", **info()), 400
    r = tareas.update_one({"_id": oid, "usuario": g.usuario}, {"$set": cambios})
    if r.matched_count == 0:
        return jsonify(error="tarea no encontrada", **info()), 404
    return jsonify(tarea=a_json(tareas.find_one({"_id": oid})), **info())


@app.delete("/api/tasks/<tarea_id>")
@requiere_token
def borrar(tarea_id):
    oid = buscar_id(tarea_id)
    r = tareas.delete_one({"_id": oid, "usuario": g.usuario}) if oid else None
    if not r or r.deleted_count == 0:
        return jsonify(error="tarea no encontrada", **info()), 404
    return jsonify(mensaje="tarea eliminada", **info())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
