FROM nginx:1.27-alpine

# Nombres de los servicios destino (se pueden cambiar por variables de entorno).
# En Kubernetes se usan nombres completos (FQDN) porque el resolver de nginx
# no usa los dominios de busqueda de /etc/resolv.conf.
ENV AUTH_HOST=auth-service \
    TASKS_HOST=tasks-service \
    DASHBOARD_HOST=dashboard-service \
    NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1

# La imagen oficial procesa /etc/nginx/templates/*.template con envsubst al arrancar
COPY templates/default.conf.template /etc/nginx/templates/default.conf.template
COPY html/ /usr/share/nginx/html/
