#!/bin/bash
set -xe

# Validate app is running on port 3000
curl -f http://localhost:3000/api/health
