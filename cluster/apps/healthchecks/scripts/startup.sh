#!/usr/bin/env bash

if ! command -v crond >/dev/null; then
  echo "crond not found"
  exit 1
fi

if ! curl --silent --fail http://localhost:8000/api/v1/status; then
  echo "healthchecks not ready"
  exit 1
fi
