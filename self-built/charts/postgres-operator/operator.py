import kopf
import kubernetes.client as k8s_client
from kubernetes import config
import psycopg2
from psycopg2 import sql
import base64
import os

# Load Kubernetes configuration
config.load_incluster_config()

core_v1_api = k8s_client.CoreV1Api()
custom_objects_api = k8s_client.CustomObjectsApi()


def get_secret_value(namespace, secret_name, key):
    """Retrieve a value from a Kubernetes secret."""
    try:
        secret = core_v1_api.read_namespaced_secret(secret_name, namespace)
        return base64.b64decode(secret.data[key]).decode('utf-8')
    except k8s_client.exceptions.ApiException as e:
        raise kopf.TemporaryError(f"Error fetching secret {secret_name}: {e}", delay=30)


def get_admin_credentials(namespace, admin_credentials):
    """Retrieve admin credentials from a secret."""
    if 'secretRef' in admin_credentials:
        secret_ref = admin_credentials['secretRef']
        username = None
        if 'usernameKey' in secret_ref:
            username = get_secret_value(namespace, secret_ref['name'], secret_ref['usernameKey'])
        else:
            username = admin_credentials['username']
        password = get_secret_value(namespace, secret_ref['name'], secret_ref['passwordKey'])
        return username, password
    else:
        raise kopf.TemporaryError("Admin credentials must be provided via secretRef.", delay=30)


def connect_to_postgres(host, port, username, password, dbname='postgres'):
    """Establish a connection to PostgreSQL."""
    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            user=username,
            password=password,
            dbname=dbname
        )
        conn.autocommit = True
        return conn
    except Exception as e:
        raise kopf.TemporaryError(f"Unable to connect to PostgreSQL: {e}", delay=30)


def list_custom_objects(group, version, plural):
    """List custom objects cluster-wide."""
    try:
        return custom_objects_api.list_cluster_custom_object(
            group=group,
            version=version,
            plural=plural
        )["items"]
    except k8s_client.exceptions.ApiException as e:
        raise kopf.TemporaryError(f"Error listing custom objects: {e}", delay=30)


def manage_user_password(secret_name, action):
    """Handle user password creation or update."""
    users = list_custom_objects("stevevaradi.me", "v1", "postgresusers")
    for user_cr in users:
        metadata = user_cr['metadata']
        spec = user_cr['spec']
        namespace = metadata['namespace']
        user_instance = spec['instance']
        user_details = spec['user']
        if user_details['passwordSecret']['name'] == secret_name:
            host = user_instance['host']
            port = user_instance.get('port', 5432)
            admin_credentials = user_instance['adminCredentials']
            username = user_details['username']

            admin_username, admin_password = get_admin_credentials(namespace, admin_credentials)
            conn = connect_to_postgres(host, port, admin_username, admin_password)
            cur = conn.cursor()

            try:
                new_password = get_secret_value(namespace, secret_name, user_details['passwordSecret']['key'])
                cur.execute(sql.SQL("ALTER USER {} WITH PASSWORD {};").format(sql.Identifier(username), sql.Identifier(new_password)))
            except Exception as e:
                raise kopf.PermanentError(f"Error {action} user password: {e}")
            finally:
                cur.close()
                conn.close()


@kopf.on.create('stevevaradi.me', 'v1', 'postgresusers')
def create_user(spec, namespace, **kwargs):
    instance = spec['instance']
    user = spec['user']

    host = instance['host']
    port = instance.get('port', 5432)
    admin_credentials = instance['adminCredentials']
    username = user['username']
    password_secret = user['passwordSecret']
    privileges = user.get('privileges', [])

    admin_username, admin_password = get_admin_credentials(namespace, admin_credentials)

    conn = connect_to_postgres(host, port, admin_username, admin_password)
    cur = conn.cursor()

    try:
        cur.execute(sql.SQL("CREATE USER {} WITH PASSWORD %s;".format(sql.Identifier(username))), [get_secret_value(namespace, password_secret['name'], password_secret['key'])])
        for privilege in privileges:
            cur.execute(sql.SQL("ALTER USER {} WITH {};".format(sql.Identifier(username), sql.SQL(privilege))))
    except Exception as e:
        raise kopf.PermanentError(f"Error creating user: {e}")
    finally:
        cur.close()
        conn.close()


@kopf.on.create('v1', 'Secret')
def create_user_password(name, **kwargs):
    """Create or sync the user's password when a Secret is created."""
    secret_name = name
    if secret_name:
        manage_user_password(secret_name, "creating")


@kopf.on.update('v1', 'Secret')
def update_user_password(name, **kwargs):
    """Update the user's password when the Secret changes."""
    secret_name = name
    if secret_name:
        manage_user_password(secret_name, "updating")


@kopf.on.create('stevevaradi.me', 'v1', 'postgresdatabases')
def create_database(spec, namespace, **kwargs):
    instance = spec['instance']
    database = spec['database']

    host = instance['host']
    port = instance.get('port', 5432)
    admin_credentials = instance['adminCredentials']
    db_name = database['dbName']
    owner = database['owner']
    owner_secret = database['ownerSecret']
    extensions = database.get('extensions', [])

    username, password = get_admin_credentials(namespace, admin_credentials)
    conn = connect_to_postgres(host, port, username, password)
    cur = conn.cursor()

    try:
        cur.execute(sql.SQL("CREATE DATABASE {};".format(sql.Identifier(db_name))))
        cur.execute(sql.SQL("GRANT ALL PRIVILEGES ON DATABASE {} TO {};".format(sql.Identifier(db_name), sql.Identifier(owner))))
    except Exception as e:
        raise kopf.PermanentError(f"Error creating database: {e}")
    finally:
        cur.close()
        conn.close()

    # Enable extensions
    enable_extensions(host, port, username, password, db_name, extensions)


@kopf.on.update('stevevaradi.me', 'v1', 'postgresdatabases')
def update_database(spec, namespace, diff, **kwargs):
    instance = spec['instance']
    database = spec['database']

    host = instance['host']
    port = instance.get('port', 5432)
    admin_credentials = instance['adminCredentials']
    db_name = database['dbName']
    extensions = database.get('extensions', [])

    username, password = get_admin_credentials(namespace, admin_credentials)
    enable_extensions(host, port, username, password, db_name, extensions)

@kopf.on.update('stevevaradi.me', 'v1', 'postgresusers')
def update_user(spec, namespace, diff, **kwargs):
    print(spec, namespace, diff)

def enable_extensions(host, port, username, password, db_name, extensions):
    """Enable PostgreSQL extensions."""
    conn = connect_to_postgres(host, port, username, password, dbname=db_name)
    cur = conn.cursor()
    try:
        cur.execute("SELECT extname FROM pg_extension;")
        installed_extensions = {row[0] for row in cur.fetchall()}

        for ext in extensions:
            if ext not in installed_extensions:
                cur.execute(sql.SQL("CREATE EXTENSION IF NOT EXISTS {} CASCADE;").format(sql.Identifier(ext)))
        for installed_ext in installed_extensions:
            if installed_ext not in extensions:
                cur.execute(sql.SQL("DROP EXTENSION IF EXISTS {};").format(sql.Identifier(installed_ext)))
    except Exception as e:
        raise kopf.PermanentError(f"Error managing extensions: {e}")
    finally:
        cur.close()
        conn.close()

