"""Drill constructor for the French section."""

import re

from questions._util import q as base

NBSP = " "


def fr(text):
    """French puts a space before ? ! : ; and inside guillemets. Make it unbreakable so it cannot wrap."""
    text = re.sub(r" (?=[?!:;»](?:\s|$|[.,)]))", NBSP, text)
    return text.replace("« ", "«" + NBSP)


def q(skill, diff, *texts):
    return base(skill, diff, *(fr(text) for text in texts))
