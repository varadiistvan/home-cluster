#!/usr/bin/env python3
"""Build Renovate's updated PostgreSQL Dockerfile with a short-lived Kaniko Job."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import ssl
import sys
import time
import urllib.error
import urllib.request


NAMESPACE = "automation"
DOCKERFILE = Path("self-built/images/postgres.Dockerfile")
CLUSTER = Path("apps/cnpg/cluster.yaml")
IMAGE = "harbor.stevevaradi.me/stevevaradi/vector-pg"
KANIKO_IMAGE = "gcr.io/kaniko-project/executor:v1.24.0-debug"
CRANE_IMAGE = "gcr.io/go-containerregistry/crane:debug"
ARCHES = ("amd64", "arm64")


def api_request(method: str, path: str, body: dict | None = None) -> dict:
    host = os.environ["KUBERNETES_SERVICE_HOST"]
    port = os.environ.get("KUBERNETES_SERVICE_PORT_HTTPS", "443")
    token = Path("/var/run/secrets/kubernetes.io/serviceaccount/token").read_text().strip()
    request = urllib.request.Request(
        f"https://{host}:{port}{path}",
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    context = ssl.create_default_context(
        cafile="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    )
    with urllib.request.urlopen(request, context=context, timeout=30) as response:
        content = response.read()
    return json.loads(content) if content else {}


def post(path: str, body: dict) -> dict:
    return api_request("POST", path, body)


def get(path: str) -> dict:
    return api_request("GET", path)


def delete(path: str) -> None:
    try:
        api_request("DELETE", path)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise


def required(pattern: str, value: str, name: str) -> str:
    match = re.search(pattern, value, re.MULTILINE)
    if not match:
        raise SystemExit(f"cannot determine {name}")
    return match.group(1)


def wait_for_job(job_path: str, name: str) -> None:
    deadline = time.monotonic() + 20 * 60
    while time.monotonic() < deadline:
        status = get(f"{job_path}/{name}").get("status", {})
        if status.get("succeeded", 0) >= 1:
            return
        if status.get("failed", 0) >= 1:
            raise SystemExit(f"build job {name} failed")
        time.sleep(5)
    raise SystemExit(f"build job {name} timed out")


def main() -> None:
    dockerfile = DOCKERFILE.read_text()
    pg_major = required(
        r"^ARG CNPG_IMAGE=.*postgresql:([0-9]+)-standard-bookworm$",
        dockerfile,
        "PostgreSQL major version",
    )
    vchord_version = required(
        r"^FROM docker\.io/tensorchord/vchord-postgres:pg[0-9]+-v([0-9]+\.[0-9]+\.[0-9]+) AS vchord$",
        dockerfile,
        "VectorChord version",
    )
    tag = f"{pg_major}-vchord-{vchord_version}"
    suffix = hashlib.sha256(dockerfile.encode()).hexdigest()[:12]
    name = f"renovate-vector-pg-{suffix}"
    base = f"harbor.stevevaradi.me/ghcr/cloudnative-pg/postgresql:{pg_major}-standard-bookworm"

    configmap = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {"name": name, "namespace": NAMESPACE},
        "data": {"postgres.Dockerfile": dockerfile},
    }
    def kaniko_job(arch: str) -> dict:
        return {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {"name": f"{name}-{arch}", "namespace": NAMESPACE},
        "spec": {
            "backoffLimit": 0,
            "ttlSecondsAfterFinished": 3600,
            "template": {
                "spec": {
                    "restartPolicy": "Never",
                    "nodeSelector": {"kubernetes.io/arch": arch},
                    "containers": [
                        {
                            "name": "kaniko",
                            "image": KANIKO_IMAGE,
                            "args": [
                                "--context=dir:///workspace",
                                "--dockerfile=/workspace/postgres.Dockerfile",
                                f"--destination={IMAGE}:{tag}-{arch}",
                                f"--build-arg=CNPG_IMAGE={base}",
                                f"--custom-platform=linux/{arch}",
                            ],
                            "volumeMounts": [
                                {"name": "docker-config", "mountPath": "/kaniko/.docker", "readOnly": True},
                                {"name": "dockerfile", "mountPath": "/workspace", "readOnly": True},
                            ],
                        }
                    ],
                    "volumes": [
                        {
                            "name": "docker-config",
                            "secret": {
                                "secretName": "registry-pass",
                                "items": [{"key": ".dockerconfigjson", "path": "config.json"}],
                            },
                        },
                        {"name": "dockerfile", "configMap": {"name": name}},
                    ],
                }
            },
        },
    }

    index_job = {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {"name": f"{name}-index", "namespace": NAMESPACE},
        "spec": {
            "backoffLimit": 0,
            "ttlSecondsAfterFinished": 3600,
            "template": {
                "spec": {
                    "restartPolicy": "Never",
                    "containers": [
                        {
                            "name": "crane",
                            "image": CRANE_IMAGE,
                            "command": ["/ko-app/crane"],
                            "args": [
                                "index",
                                "append",
                                "-t",
                                f"{IMAGE}:{tag}",
                                "-m",
                                f"{IMAGE}:{tag}-amd64",
                                "-m",
                                f"{IMAGE}:{tag}-arm64",
                            ],
                            "volumeMounts": [
                                {"name": "docker-config", "mountPath": "/root/.docker", "readOnly": True},
                            ],
                        }
                    ],
                    "volumes": [
                        {
                            "name": "docker-config",
                            "secret": {
                                "secretName": "registry-pass",
                                "items": [{"key": ".dockerconfigjson", "path": "config.json"}],
                            },
                        }
                    ],
                }
            },
        },
    }

    if "--dry-run" in sys.argv:
        print(
            json.dumps(
                {
                    "configmap": configmap,
                    "kaniko_jobs": [kaniko_job(arch) for arch in ARCHES],
                    "index_job": index_job,
                },
                indent=2,
            )
        )
        return

    configmap_path = f"/api/v1/namespaces/{NAMESPACE}/configmaps"
    job_path = f"/apis/batch/v1/namespaces/{NAMESPACE}/jobs"
    try:
        post(configmap_path, configmap)
        for arch in ARCHES:
            post(job_path, kaniko_job(arch))
        for arch in ARCHES:
            wait_for_job(job_path, f"{name}-{arch}")
        post(job_path, index_job)
        wait_for_job(job_path, f"{name}-index")
    finally:
        delete(f"{configmap_path}/{name}")

    old = CLUSTER.read_text()
    new, count = re.subn(
        r"(?m)^  imageName: harbor\.stevevaradi\.me/stevevaradi/vector-pg:[^\s]+$",
        f"  imageName: {IMAGE}:{tag}",
        old,
    )
    if count != 1:
        raise SystemExit(f"expected one PostgreSQL imageName, found {count}")
    CLUSTER.write_text(new)


if __name__ == "__main__":
    main()
