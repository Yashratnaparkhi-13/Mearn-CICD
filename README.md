# MERN CI/CD Demo — GitLab CI, Docker, Kubernetes, Blue-Green & Canary

A complete, beginner-friendly MERN (MongoDB, Express, React, Node.js) project
wired up with a full GitLab CI/CD pipeline: automated linting, testing, code
quality checks, Docker builds, and Kubernetes deployments using both
**blue-green** and **canary** release strategies.

📄 **See `MERN_CICD_Beginners_Guide.docx` for the full step-by-step explanation.**

## Project structure

```
mern-cicd-project/
├── backend/              # Express.js REST API (Todo app)
├── frontend/              # React single-page app
├── k8s/                   # Kubernetes manifests (staging, blue-green, canary)
├── scripts/                # Deployment automation scripts (bash)
├── docker-compose.yml     # Run the whole stack locally
└── .gitlab-ci.yml         # The CI/CD pipeline definition
```

## Run locally (no Kubernetes needed)

```bash
docker compose up --build
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:5000/api/todos
- MongoDB: localhost:27017

## Run without Docker

```bash
# Terminal 1
cd backend
cp .env.example .env
npm install
npm run dev

# Terminal 2
cd frontend
npm install
npm start
```

## Run the tests

```bash
cd backend && npm test
cd frontend && npm test
```

## Push to GitLab and watch the pipeline run

1. Create a new empty project on GitLab.
2. `git init && git remote add origin <your-gitlab-repo-url>`
3. `git add . && git commit -m "Initial commit" && git push -u origin main`
4. Go to **Settings → CI/CD → Variables** and add the variables listed in
   the Word guide (KUBE_CONTEXT, REACT_APP_API_URL, etc.).
5. Open **Build → Pipelines** to watch it run automatically.

## Deploy through Jenkins to AWS EKS

The root `Jenkinsfile` runs backend and frontend tests, builds and pushes both
images to Amazon ECR, and deploys the staging namespace to the
`mern-cicd-eks` cluster in `ap-south-1`. Configure the Jenkins agent with AWS
permissions for ECR and EKS, plus `aws`, `kubectl`, `envsubst`, Docker, Node.js,
and npm. Add a Jenkins **Secret text** credential named `mern-mongo-uri` with
the MongoDB connection string before running the pipeline. Do not commit or
paste the connection string into source files.

The frontend is served through an AWS load balancer and proxies `/api` requests
to the in-cluster backend service, so the frontend image does not need a
hard-coded public backend URL.

## Deployment strategies included

| Strategy | Script | What it does |
|---|---|---|
| Staging | `.gitlab-ci.yml` → `deploy:staging` | Simple rolling deploy, auto-runs on every merge to `main` |
| Blue-Green | `scripts/blue-green-deploy.sh` | Deploys new version alongside old, smoke-tests it, then flips 100% of traffic instantly |
| Canary | `scripts/canary-deploy.sh <percent>` | Gradually shifts a % of production traffic to the new version |

All production deploy jobs are `when: manual` in the pipeline — this is a
safety gate so nothing reaches real users without a human clicking "deploy".
