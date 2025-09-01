#!/bin/bash
set -xe

curl -f http://localhost:3000/api/health || exit 1
