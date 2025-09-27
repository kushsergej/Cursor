#!/bin/bash

python -m pip install --upgrade uv
uv venv .venv --python 3.13 --clear
source .venv/Scripts/activate

uv add dotenv

# uv run main.py