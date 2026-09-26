# Primera práctica de Ansible: Desafío de depuración

Playbook que crea un usuario, instala Apache, copia una página de inicio y habilita el servicio web en localhost (Ubuntu).

## Estructura
PARCIAL_1_PRACTICA_1/
├── inventario
├── playbook.yml
└── files/
└── index.html

## Errores corregidos

| # | Original | Problema | Corrección |
|---|---|---|---|
| 1 | `—` | Encabezado YAML inválido | `---` |
| 2 | Indentación | `tasks` y parámetros mal indentados | Indentación correcta de YAML |
| 3 | `shell: "/bin/shh"` | Shell inexistente | `/bin/bash` |
| 4 | `ansible.builtin.yum` | Ubuntu no usa yum | `ansible.builtin.apt` |
| 5 | `name: apache` / `httpd` | Nombre de paquete incorrecto en Ubuntu | `apache2` |
| 6 | `state: install` | Valor inválido | `state: present` |
| 7 | `files/index.htmml` | Extensión mal escrita | `files/index.html` |
| 8 | `/var/www/htlm/` | Ruta mal escrita | `/var/www/html/` |
| 9 | `mode: "644"` | Buena práctica: 4 dígitos | `"0644"` |
| 10 | `state: running` | Valor inválido en el módulo service | `state: started` |
| 11 | `copy` / `service` | Nombres sin FQCN | `ansible.builtin.copy` / `ansible.builtin.service` |

## Problema adicional del entorno

Ubuntu reciente usa `sudo-rs`, cuyo prompt de contraseña no es reconocido por Ansible (timeout en become). Se resolvió agregando `ansible_become_exe=sudo.ws` en el inventario.

## Ejecución

```bash
ansible-playbook -i inventario playbook.yml --syntax-check
ansible-playbook -i inventario playbook.yml -K
```

Resultado: `ok=5  changed=3  failed=0`

## Verificación

```bash
id Clase
systemctl status apache2 --no-pager
curl http://localhost
```
