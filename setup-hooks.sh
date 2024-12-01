#!/bin/bash
git config core.hooksPath .hooks
chmod +x .hooks/pre-commit
chmod +x .hooks/commit-msg
