"""Shared constructor for drill tuples."""


def q(skill, diff, prompt, correct, w1, w2, w3, why):
    return (skill, diff, prompt, correct, [w1, w2, w3], why)
