# AWS Blue/Green Deployment — End-to-End CI/CD Guide

This document describes the complete Blue/Green CI/CD implementation for a Next.js 14 application on AWS. It covers the architecture, purpose, and detailed behavior of each AWS service and repository component used to build, deploy, and operate the application. All steps and configurations reflect the implemented setup.

- Pipeline: `nextjs-bg-pipeline`
- CodeBuild: `nextjs-bg-codebuild`
- CodeDeploy: `nextjs-bg-app` / `nextjs-bg-dg`
- S3 Artifact Bucket: `nextjsbg-artifacts-856107418937-ap-south-1`
- ALB: `nextjs-public-alb`
- Target Groups: `nextjs-blue-tg` (initially 100%), `nextjs-green-tg` (initially 0%)
- EC2 Instances tagged: `Blue-Instance`, `Green-Instance`
- Health endpoint: `/api/health`
- Runtime: Next.js 14 (React 18), Node.js 18, port 3000, managed by systemd

---

## 1) Architecture and Flow

1. Code is pushed to the `main` branch in GitHub.
2. CodePipeline (`nextjs-bg-pipeline`) triggers automatically via GitHub webhook.
3. CodeBuild (`nextjs-bg-codebuild`) builds the application using `buildspec.yml`, packages a deployment-ready artifact, and uploads it to S3 (`nextjsbg-artifacts-856107418937-ap-south-1`).
4. CodePipeline triggers CodeDeploy (`nextjs-bg-app` / `nextjs-bg-dg`).
5. CodeDeploy agents on the EC2 instances retrieve the artifact and execute lifecycle hooks defined in `appspec.yml`.
6. Application Load Balancer routes traffic to the active (Blue) target group. After validation of the new (Green) version, traffic shifts to Green using weighted routing or CodeDeploy traffic shifting.

**Why this architecture:**
- Ensures zero-downtime releases by deploying Green alongside Blue and shifting traffic after validation.
- Isolates build, artifact storage, and deployment responsibilities across CodeBuild, S3, and CodeDeploy.
- Uses ALB Target Groups to safely switch versions and facilitate quick rollback.

---

## Architecture Diagram

```mermaid
graph LR
  GITHUB[GitHub (main)] --> PIPE[CodePipeline]
  PIPE --> BUILD[CodeBuild (buildspec.yml)]
  BUILD --> ARTIFACTS[S3 Artifact Bucket]
  ARTIFACTS --> DEPLOY[CodeDeploy (Blue/Green)]
  PIPE --> DEPLOY

  DEPLOY -->|Lifecycle hooks<br/>(appspec.yml + scripts)| BLUE[ASG: Blue]
  DEPLOY -->|Lifecycle hooks<br/>(appspec.yml + scripts)| GREEN[ASG: Green]

  subgraph Runtime
    ALB[ALB: nextjs-public-alb]
    TGB[Target Group: nextjs-blue-tg]
    TGG[Target Group: nextjs-green-tg]
    ALB --> TGB
    ALB --> TGG
    TGB --> EC2B[EC2 Instances (Blue)]
    TGG --> EC2G[EC2 Instances (Green)]
  end

  USERS[Internet Users] --> ALB

  SSM[SSM Association<br/>(CodeDeploy agent updates)] --> EC2B
  SSM --> EC2G

  HEALTH[/api/health<br/>(200 OK)/] -.-> ALB
  NOTE[Next.js 14 / Node 18<br/>systemd on port 3000] -.-> EC2B
  NOTE -.-> EC2G
```

---

## 2) Core AWS Services and Purpose

- **GitHub (Source):** Stores the application code. A webhook triggers the pipeline on `main` pushes for automated deployments.
- **AWS CodePipeline:** Orchestrates the CI/CD stages: Source → Build → Deploy. Provides visibility and traceability of each run.
- **AWS CodeBuild:** Builds the Next.js application with Node 18, runs `npm ci` and `npm run build`, and prepares artifacts for deployment.
- **Amazon S3 (Artifact Store):** Stores versioned build artifacts for CodeDeploy to consume, enabling repeatable and auditable deployments.
- **AWS CodeDeploy (Blue/Green):** Automates deployment to EC2 with lifecycle hooks and coordinates traffic shifting between Blue and Green target groups.
- **Application Load Balancer:** Routes external traffic to the active version via Target Groups, enabling weighted traffic shifting.
- **Target Groups (Blue/Green):** Represent two independent sets of healthy instances, allowing safe cutover from Blue to Green.
- **Auto Scaling Groups & Launch Templates:** Provide managed groups of instances for Blue and Green, ensuring consistent configuration (AMI, instance type, SGs) and scalable capacity.
- **AWS Systems Manager (SSM):** Maintains the CodeDeploy agent on instances (via Association) and optionally provides parameterized environment variables during the build.

---

## 3) Repository Structure (Key Files)

- `buildspec.yml` — CodeBuild instructions to install, build, and package artifacts.
- `appspec.yml` — CodeDeploy mapping of files and lifecycle hooks for EC2 deployment.
- `scripts/` — Shell scripts executed by CodeDeploy hooks and utilities.
- `systemd/nextjs.service` — Systemd unit to manage the Next.js process on EC2.
- `package.json` — Next.js app scripts and dependencies.
- `app/api/health/route.js` — Health endpoint used for validation and Target Group health checks.
- `next.config.js` — Next.js configuration.

---

## 4) Build Process (CodeBuild via `buildspec.yml`)

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 18
    commands:
      - "echo 'Installing prerequisites'"
      - "if command -v apt-get >/dev/null 2>&1; then apt-get update -y || true && apt-get install -y jq unzip || true; fi"
      - "node -v && npm -v"

  pre_build:
    commands:
      - "echo 'Pre-build step: fetch environment variables (optional)'"
      - "chmod +x scripts/fetch_ssm_env.sh"
      - "./scripts/fetch_ssm_env.sh || true"

  build:
    commands:
      - "echo 'Installing app dependencies'"
      - "npm ci"
      - "echo 'Building Next.js app'"
      - "npm run build"

  post_build:
    commands:
      - "echo 'Preparing artifact for CodeDeploy'"
      - "ARTIFACT_DIR=build_artifact"
      - "mkdir -p \"$ARTIFACT_DIR\""
      - "cp -r .next public app package.json package-lock.json next.config.js scripts systemd appspec.yml \"$ARTIFACT_DIR\"/"
      - "echo 'Making all scripts executable'"
      - "chmod +x \"$ARTIFACT_DIR\"/scripts/*.sh"
      - "echo 'Listing artifact contents for verification'"
      - "ls -l \"$ARTIFACT_DIR\""
      - "echo 'Listing scripts permissions'"
      - "ls -l \"$ARTIFACT_DIR/scripts\""
      - "echo 'Listing systemd service'"
      - "ls -l \"$ARTIFACT_DIR/systemd\""
      - "echo 'Checking appspec.yml'"
      - "ls -l \"$ARTIFACT_DIR/appspec.yml\""

artifacts:
  base-directory: build_artifact
  files:
    - '**/*'
```

**Rationale:**
- Uses Node 18 to match runtime and ensure compatibility.
- `npm ci` ensures deterministic installs based on `package-lock.json`.
- Artifacts include app build, scripts, systemd unit, and `appspec.yml` so the deployment has everything needed.
- Optional SSM parameter fetch supports secure environment variables during build.

---

## 5) Deployment Process (CodeDeploy via `appspec.yml`)

```yaml
version: 0.0
os: linux

files:
  - source: /
    destination: /srv/nextjs
    overwrite: true

hooks:
  ApplicationStop:
    - location: scripts/stop_server.sh
      timeout: 300
      runas: root

  BeforeInstall:
    - location: scripts/before_install.sh
      timeout: 600
      runas: root

  AfterInstall:
    - location: scripts/after_install.sh
      timeout: 1200
      runas: root

  ApplicationStart:
    - location: scripts/start_server.sh
      timeout: 300
      runas: root

  ValidateService:
    - location: scripts/validate_service.sh
      timeout: 120
      runas: root
```

**Rationale:**
- Deploys to `/srv/nextjs` for a clean, consistent application directory.
- Lifecycle hooks ensure graceful stop, correct environment preparation, dependency installation, service start, and post-start validation.

### 5.1 Lifecycle Scripts Explained

- `scripts/stop_server.sh`
  - Stops the existing service and any stray Node processes to avoid port conflicts.
  - Idempotent and safe to run even if nothing is active.
  ```bash
  sudo systemctl stop nextjs || true
  sudo pkill -f "npm run start" || true
  ```

- `scripts/before_install.sh`
  - Ensures `/srv/nextjs` exists with correct ownership.
  - Installs Node.js 18 if it’s not present on the instance.
  - Cleans old application artifacts to prevent stale deployments.
  ```bash
  mkdir -p /srv/nextjs
  chown -R ubuntu:ubuntu /srv/nextjs
  if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
  fi
  rm -rf "/srv/nextjs/.next" "/srv/nextjs/app" "/srv/nextjs/package.json" "/srv/nextjs/package-lock.json" || true
  ```

- `scripts/after_install.sh`
  - Installs production dependencies via `npm ci --only=production` for lean deployment footprint.
  - Copies and enables the systemd service for consistent process management across reboots.
  - Resets ownership to `ubuntu:ubuntu`.
  ```bash
  cd /srv/nextjs
  npm ci --only=production
  if [ -f /srv/nextjs/systemd/nextjs.service ]; then
    sudo cp /srv/nextjs/systemd/nextjs.service /etc/systemd/system/nextjs.service
    sudo chmod 644 /etc/systemd/system/nextjs.service
    sudo systemctl daemon-reload
    sudo systemctl enable nextjs
  fi
  chown -R ubuntu:ubuntu /srv/nextjs
  ```

- `scripts/start_server.sh`
  - Ensures a valid systemd unit exists (creates a default one if missing) and restarts the service.
  ```bash
  # Writes default unit if absent
  systemctl daemon-reload
  systemctl enable nextjs
  systemctl restart nextjs
  ```

- `scripts/validate_service.sh`
  - Polls `http://127.0.0.1:3000/api/health` for HTTP 200 to confirm the service is healthy before traffic shifting.
  ```bash
  for i in {1..12}; do
    curl -sf http://127.0.0.1:3000/api/health && exit 0
    sleep 5
  done
  exit 1
  ```

### 5.2 Systemd Service

`systemd/nextjs.service` manages the app as a long-running service on port 3000:

```ini
[Service]
Type=simple
User=ubuntu
WorkingDirectory=/srv/nextjs
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=HOST=0.0.0.0
ExecStart=/usr/bin/env PORT=$PORT HOST=$HOST /usr/bin/npm run start
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
```

**Rationale:**
- Provides reliable process management, automatic restart, and integration with `journalctl` for logs.

### 5.3 Health Endpoint

`app/api/health/route.js` returns HTTP 200 and is used by validation and Target Group health checks:

```javascript
export async function GET() {
  return new Response(JSON.stringify({ status: 'ok' }), {
    status: 200,
    headers: { 'content-type': 'application/json' }
  });
}
```

**Rationale:**
- A lightweight, deterministic health probe ensures instances are only marked healthy when the app is ready.

---

## 6) Load Balancing and Traffic Shifting

- **ALB:** `nextjs-public-alb` (internet-facing) with HTTP:80 listener.
- **Target Groups:**
  - `nextjs-blue-tg`: starts at 100% traffic.
  - `nextjs-green-tg`: starts at 0% traffic.
- **Traffic shifting:** After a successful deployment and health validation, traffic is shifted from Blue to Green using weighted routing through the ALB listener or managed by CodeDeploy.

**Rationale:**
- Blue/Green with ALB Target Groups enables safe rollouts, instant rollback, and minimal downtime.

---

## 7) Compute: ASGs and Launch Templates

- Separate Auto Scaling Groups (ASGs) represent Blue and Green environments, each linked to its corresponding Target Group.
- Launch Templates define AMI, instance type, security groups, and any required settings.
- Desired/Min/Max capacity is configured per environment to maintain availability during deployments.

**Rationale:**
- Independent Blue and Green capacity provides isolation between the current production version and the new candidate version.

---

## 8) Systems Manager (SSM) Integration

- An SSM Association installs/updates the CodeDeploy agent on instances tagged with `Name: Blue-Instance` and `Name: Green-Instance` on a 14-day schedule.
- Optionally, `scripts/fetch_ssm_env.sh` can fetch parameters from SSM during the build when `SSM_PREFIX` and `REGION` are provided as environment variables in CodeBuild, producing `.env.production` for the app.

**Rationale:**
- Ensures the CodeDeploy agent remains current and reduces manual maintenance.
- Centralizes configuration and secrets via SSM Parameter Store for builds.

---

## 9) CodePipeline Configuration

1. **Source (GitHub):** Uses `main` as the deployment branch; a webhook triggers the pipeline.
2. **Build (CodeBuild):** Uses `nextjs-bg-codebuild` with `buildspec.yml` to produce artifacts.
3. **Deploy (CodeDeploy):** Uses `nextjs-bg-app` / `nextjs-bg-dg` to deploy to EC2 with Blue/Green settings.
4. **Artifact Store (S3):** Uses `nextjsbg-artifacts-856107418937-ap-south-1` for pipeline artifacts.

**Rationale:**
- Provides an automated, traceable, and repeatable path from commit to production with clear separation of concerns.

---

## 10) Rebuild Checklist

1. Prepare VPC, subnets, and routing.
2. Configure Security Groups:
   - ALB SG: allow inbound 80 from the internet; outbound to EC2 SG.
   - EC2 SG: allow inbound 3000 from ALB SG only.
3. Create ALB `nextjs-public-alb` with HTTP:80 listener and health checks at `/api/health` on port 3000.
4. Create Target Groups: `nextjs-blue-tg` and `nextjs-green-tg`.
5. Create Launch Templates and ASGs for Blue and Green; attach to the corresponding Target Groups.
6. Attach IAM Instance Profile with SSM and CodeDeploy agent permissions to EC2.
7. Configure SSM Association to install/update the CodeDeploy agent for instances tagged as Blue and Green.
8. Create CodeDeploy Application `nextjs-bg-app` and Deployment Group `nextjs-bg-dg` with Blue/Green and ALB/Target Groups.
9. Create CodeBuild project `nextjs-bg-codebuild` (Node 18) using `buildspec.yml` from the repo.
10. Create CodePipeline `nextjs-bg-pipeline` with Source (GitHub `main`), Build (CodeBuild), Deploy (CodeDeploy), and S3 artifact store.
11. Push to `main` to trigger the pipeline and verify deployment and health.
12. Shift traffic to Green after validation (automated or manual weight change), keeping Blue available for quick rollback as needed.