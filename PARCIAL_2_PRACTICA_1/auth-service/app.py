"""
auth-service: registra usuarios y emite tokens JWT.
Es el UNICO servicio que conoce las contrasenas. Tiene su propia base de datos (mongo-auth).
"""
import os
import socket
import datetime

import bcrypt
import jwt
from flask import Flask, jsonify, request
from pymongo import MongoClient, errors

app = Flask(__name__)

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/authdb")
JWT_SECRET = os.getenv("JWT_SECRET", "cambia-este-secreto")
JWT_HORAS = int(os.getenv("JWT_HORAS", "1"))
VERSION = os.getenv("APP_VERSION", "1.0")

client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=3000)
db = client.get_default_database()
usuarios = db["usuarios"]


def info():
    """Datos que identifican que contenedor/pod respondio (util al escalar)."""
    return {"servicio": "auth-service", "version": VERSION, "atendido_por": socket.gethostname()}


@app.get("/health")
def health():
    try:
        client.admin.command("ping")
        return jsonify(status="ok", **info())
    except errors.PyMongoError:
        return jsonify(status="sin base de datos", **info()), 503


@app.post("/api/auth/register")
def register():
    datos = request.get_json(silent=True) or {}
    username = (datos.get("username") or "").strip().lower()
    password = datos.get("password") or ""
    if len(username) < 3 or len(password) < 6:
        return jsonify(error="usuario (min 3) y contrasena (min 6) requeridos", **info()), 400

    # Indice unico: dos usuarios no pueden tener el mismo username
    usuarios.create_index("username", unique=True)
    hash_pw = bcrypt.hashpw(password.encode(), bcrypt.gensalt())
    try:
        usuarios.insert_one({"username": username, "password": hash_pw,
                             "creado": datetime.datetime.now(datetime.timezone.utc)})
    except errors.DuplicateKeyError:
        return jsonify(error="el usuario ya existe", **info()), 409
    return jsonify(mensaje=f"usuario {username} creado", **info()), 201


@app.post("/api/auth/login")
def login():
    datos = request.get_json(silent=True) or {}
    username = (datos.get("username") or "").strip().lower()
    password = datos.get("password") or ""
    usuario = usuarios.find_one({"username": username})
    if not usuario or not bcrypt.checkpw(password.encode(), usuario["password"]):
        return jsonify(error="credenciales invalidas", **info()), 401

    ahora = datetime.datetime.now(datetime.timezone.utc)
    token = jwt.encode(
        {"sub": username, "iat": ahora, "exp": ahora + datetime.timedelta(hours=JWT_HORAS)},
        JWT_SECRET, algorithm="HS256")
    return jsonify(token=token, username=username, **info())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
