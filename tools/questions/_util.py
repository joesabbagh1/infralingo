"""Shared constructors for drill tuples."""

ROADMAP = "roadmap.sh"
IX = "iximiuz"
VAULT = "tech-vault"
BLUE = "devsec blueprint"
AWESOME = "awesome-devsecops"
RAE = "raesene"


def q(skill, diff, prompt, correct, w1, w2, w3, why, source=ROADMAP, url="https://roadmap.sh/devops"):
    return (skill, diff, prompt, correct, [w1, w2, w3], why, source, url)
