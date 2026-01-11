web: /home/frappe/frappe-bench/env/bin/gunicorn --chdir=/home/frappe/frappe-bench/sites --bind=0.0.0.0:8000 --workers=${GUNICORN_WORKERS:-4} --timeout=120 --worker-class=gthread --threads=4 frappe.app:application
socketio: node /home/frappe/frappe-bench/apps/frappe/socketio.js
schedule: bench schedule
worker: bench worker --queue default,short,long
