"""Craft AI interview preparation, entirely in French."""

from questions.craft_ai.ai import QUESTIONS as AI
from questions.craft_ai.company import QUESTIONS as COMPANY
from questions.craft_ai.containers import QUESTIONS as CONTAINERS
from questions.craft_ai.linux import QUESTIONS as LINUX
from questions.craft_ai.network import QUESTIONS as NETWORK
from questions.craft_ai.platform import QUESTIONS as PLATFORM
from questions.craft_ai.reliability import QUESTIONS as RELIABILITY

QUESTIONS = COMPANY + LINUX + NETWORK + CONTAINERS + PLATFORM + RELIABILITY + AI
