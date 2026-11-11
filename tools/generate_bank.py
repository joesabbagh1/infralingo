#!/usr/bin/env python3
"""Build the Infralingo question bank from the curated drills."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "app" / "src" / "main" / "assets" / "content"

CATEGORIES = [
    {"id": "linux", "title": "Linux", "order": 1, "blurb": "Processes, systemd, permissions, storage, and the host itself."},
    {"id": "networking", "title": "Networking", "order": 2, "blurb": "The protocols and failure modes an operator actually hits."},
    {"id": "servers", "title": "Servers and edge", "order": 3, "blurb": "Proxies and web servers in front of the workload."},
    {"id": "containers", "title": "Containers", "order": 4, "blurb": "Images, runtimes, networking, and the Docker security model."},
    {"id": "kubernetes", "title": "Kubernetes", "order": 5, "blurb": "Workloads, traffic, scheduling, storage, and cluster failure."},
    {"id": "cicd", "title": "CI/CD", "order": 6, "blurb": "Pipelines, artifacts, and the path from git to a running release."},
    {"id": "iac", "title": "Infrastructure as code", "order": 7, "blurb": "Terraform, Ansible, and policy around the change."},
    {"id": "cloud", "title": "Cloud infrastructure", "order": 8, "blurb": "Identity, networks, compute, and the shared responsibility line."},
    {"id": "observability", "title": "Observability", "order": 9, "blurb": "Logs, metrics, traces, and alerts you can act on."},
    {"id": "security", "title": "Infra security", "order": 10, "blurb": "Identity, supply chain, admission, runtime, and containment."},
]

SKILLS = [
    ("linux-processes", "linux", "Processes", 1),
    ("linux-signals", "linux", "Signals", 2),
    ("linux-systemd", "linux", "systemd", 3),
    ("linux-users", "linux", "Users and groups", 4),
    ("linux-permissions", "linux", "Permissions", 5),
    ("linux-files", "linux", "Files and links", 6),
    ("linux-disks", "linux", "Disks and filesystems", 7),
    ("linux-mounts", "linux", "Mounts", 8),
    ("linux-packages", "linux", "Packages", 9),
    ("linux-shell", "linux", "Shell", 10),
    ("linux-text", "linux", "Text processing", 11),
    ("linux-ssh", "linux", "SSH", 12),
    ("linux-logs", "linux", "Logs", 13),
    ("linux-cgroups", "linux", "cgroups", 14),
    ("linux-namespaces", "linux", "Namespaces", 15),
    ("linux-netfilter", "linux", "Host firewall", 16),
    ("linux-troubleshooting", "linux", "Troubleshooting a host", 17),
    ("net-osi", "networking", "Layers and segments", 1),
    ("net-ip", "networking", "IP and subnets", 2),
    ("net-routing", "networking", "Routing", 3),
    ("net-dns", "networking", "DNS", 4),
    ("net-tcp", "networking", "TCP and UDP", 5),
    ("net-http", "networking", "HTTP", 6),
    ("net-tls", "networking", "TLS", 7),
    ("net-tunnels", "networking", "SSH tunnels", 8),
    ("net-firewall", "networking", "Firewalls and ACLs", 9),
    ("net-nat", "networking", "NAT", 10),
    ("net-proxy", "networking", "Proxies", 11),
    ("net-lb", "networking", "Load balancing", 12),
    ("net-cloud", "networking", "Cloud networking", 13),
    ("net-dual", "networking", "Dual-homed hosts", 14),
    ("net-l2", "networking", "Bridges, VLANs, and switches", 15),
    ("srv-nginx", "servers", "Nginx", 1),
    ("srv-apache", "servers", "Apache", 2),
    ("srv-caddy", "servers", "Caddy", 3),
    ("srv-envoy", "servers", "Envoy", 4),
    ("srv-cache", "servers", "Caching", 5),
    ("ctr-images", "containers", "Images and layers", 1),
    ("ctr-dockerfile", "containers", "Dockerfiles", 2),
    ("ctr-multistage", "containers", "Multi-stage builds", 3),
    ("ctr-registries", "containers", "Registries and tags", 4),
    ("ctr-volumes", "containers", "Volumes and mounts", 5),
    ("ctr-networks", "containers", "Container networks", 6),
    ("ctr-ports", "containers", "Published ports", 7),
    ("ctr-compose", "containers", "Compose", 8),
    ("ctr-runtime", "containers", "Runtimes", 9),
    ("ctr-security", "containers", "Docker security model", 10),
    ("ctr-secrets", "containers", "Build secrets", 11),
    ("ctr-containerd", "containers", "containerd and CRI", 12),
    ("ctr-rootless", "containers", "Rootless and user namespaces", 13),
    ("ctr-debug", "containers", "Debugging containers", 14),
    ("k8s-pods", "kubernetes", "Pods", 1),
    ("k8s-workloads", "kubernetes", "Workload types", 2),
    ("k8s-config", "kubernetes", "ConfigMaps", 3),
    ("k8s-secrets", "kubernetes", "Secrets", 4),
    ("k8s-services", "kubernetes", "Services", 5),
    ("k8s-ingress", "kubernetes", "Ingress and Gateway", 6),
    ("k8s-probes", "kubernetes", "Probes", 7),
    ("k8s-resources", "kubernetes", "Requests, limits, QoS", 8),
    ("k8s-scheduling", "kubernetes", "Scheduling", 9),
    ("k8s-storage", "kubernetes", "Storage", 10),
    ("k8s-rbac", "kubernetes", "RBAC", 11),
    ("k8s-netpol", "kubernetes", "NetworkPolicy", 12),
    ("k8s-psa", "kubernetes", "Pod Security", 13),
    ("k8s-helm", "kubernetes", "Helm", 14),
    ("k8s-gitops", "kubernetes", "GitOps", 15),
    ("k8s-hpa", "kubernetes", "Autoscaling", 16),
    ("k8s-debug", "kubernetes", "Debugging workloads", 17),
    ("k8s-dns", "kubernetes", "Cluster DNS and certs", 18),
    ("cicd-git", "cicd", "Git", 1),
    ("cicd-actions", "cicd", "GitHub Actions", 2),
    ("cicd-jenkins", "cicd", "Jenkins", 3),
    ("cicd-artifacts", "cicd", "Artifacts", 4),
    ("cicd-promotion", "cicd", "Promotion", 5),
    ("cicd-runners", "cicd", "Runners", 6),
    ("cicd-supply", "cicd", "Pipeline supply chain", 7),
    ("iac-workflow", "iac", "Terraform workflow", 1),
    ("iac-state", "iac", "Terraform state", 2),
    ("iac-modules", "iac", "Modules", 3),
    ("iac-plan", "iac", "Plan and apply", 4),
    ("iac-policy", "iac", "Policy as code", 5),
    ("iac-ansible", "iac", "Ansible and config management", 6),
    ("iac-secrets", "iac", "Secrets in automation", 7),
    ("cloud-iam", "cloud", "Cloud IAM", 1),
    ("cloud-vpc", "cloud", "VPC and subnets", 2),
    ("cloud-sg", "cloud", "Security groups and NACLs", 3),
    ("cloud-compute", "cloud", "Compute", 4),
    ("cloud-lb", "cloud", "Cloud load balancers", 5),
    ("cloud-registry", "cloud", "Cloud registries", 6),
    ("cloud-object", "cloud", "Object storage", 7),
    ("cloud-regions", "cloud", "Regions and failure", 8),
    ("obs-logs", "observability", "Logs", 1),
    ("obs-metrics", "observability", "Metrics", 2),
    ("obs-traces", "observability", "Traces", 3),
    ("obs-prometheus", "observability", "Prometheus and Grafana", 4),
    ("obs-otel", "observability", "OpenTelemetry", 5),
    ("obs-alerts", "observability", "Alerts", 6),
    ("sec-least", "security", "Least privilege", 1),
    ("sec-secrets", "security", "Secrets management", 2),
    ("sec-pki", "security", "PKI and certificates", 3),
    ("sec-image", "security", "Image and dependency scanning", 4),
    ("sec-sbom", "security", "SBOM and signing", 5),
    ("sec-pipeline", "security", "Pipeline hardening", 6),
    ("sec-runtime", "security", "Runtime detection", 7),
    ("sec-audit", "security", "Audit logs", 8),
    ("sec-incident", "security", "Containment", 9),
    ("sec-zero", "security", "Zero trust", 10),
    ("sec-threat", "security", "Threat modeling", 11),
    ("sec-vault", "security", "Vault and OpenBao", 12),
    ("sec-bench", "security", "Benchmarks and host audit", 13),
    ("sec-cspm", "security", "Cloud posture", 14),
]


def rotate(correct: str, wrongs: list[str], key: str) -> tuple[list[str], int]:
    choices = [correct, *wrongs]
    if len(choices) != 4 or len(set(choices)) != 4:
        raise SystemExit(f"bad choices for {key}: {choices}")
    shift = int(hashlib.sha256(key.encode()).hexdigest(), 16) % 4
    rotated = choices[shift:] + choices[:shift]
    return rotated, rotated.index(correct)


def main() -> None:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from questions import ALL

    skill_ids = {item[0] for item in SKILLS}
    built = []
    counts: dict[str, int] = {}
    for raw in ALL:
        skill, diff, prompt, correct, wrongs, why = raw
        if skill not in skill_ids:
            raise SystemExit(f"unknown skill {skill}")
        if diff not in {"easy", "medium", "hard"}:
            raise SystemExit(f"bad difficulty on {skill}")
        counts[skill] = counts.get(skill, 0) + 1
        qid = f"{skill}-{counts[skill]:02d}"
        choices, answer = rotate(correct, list(wrongs), qid)
        built.append(
            {
                "id": qid,
                "skillId": skill,
                "difficulty": diff,
                "prompt": prompt,
                "choices": choices,
                "answer": answer,
                "explanation": why,
            }
        )

    missing = [skill for skill, *_ in SKILLS if counts.get(skill, 0) < 4]
    if missing:
        raise SystemExit("skills under 4 questions: " + ", ".join(missing))

    by_category: dict[str, list[dict]] = {item["id"]: [] for item in CATEGORIES}
    skill_category = {skill: category for skill, category, *_ in SKILLS}
    for question in built:
        by_category[skill_category[question["skillId"]]].append(question)

    questions_dir = ROOT / "questions"
    questions_dir.mkdir(parents=True, exist_ok=True)
    files = []
    for category in CATEGORIES:
        name = f"{category['id']}.json"
        files.append(name)
        payload = by_category[category["id"]]
        (questions_dir / name).write_text(json.dumps(payload, indent=2) + "\n")

    (ROOT / "categories.json").write_text(json.dumps(CATEGORIES, indent=2) + "\n")
    skills = [
        {"id": skill, "categoryId": category, "title": title, "order": order}
        for skill, category, title, order in SKILLS
    ]
    (ROOT / "skills.json").write_text(json.dumps(skills, indent=2) + "\n")
    (ROOT / "manifest.json").write_text(json.dumps({"questionFiles": files}, indent=2) + "\n")
    print(f"wrote {len(built)} questions across {len(SKILLS)} skills")


if __name__ == "__main__":
    main()
