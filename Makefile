# Variables
REPO_URL ?= https://github.com/viaacode/tkn-demo.git
SSH_REPO_URL ?= git@github.com:viaacode/tkn-demo.git

.PHONY: help build run clean docker-build docker-run test setup-auth test-github-auth

help:
	@echo "🚀 Tekton Demo App - Available targets:"
	@echo "  make setup-auth         - Setup GitHub SSH auth for Tekton"
	@echo "  make build              - Build Go binary locally"
	@echo "  make run                - Run the application"
	@echo "  make test               - Test HTTP endpoints"
	@echo "  make test-github-auth   - Test GitHub SSH authentication"
	@echo "  make docker-build       - Build Docker image"
	@echo "  make docker-run         - Run Docker container"
	@echo "  make clean              - Clean build artifacts"
	@echo "  make tekton-apply       - Apply Tekton pipeline to cluster"
	@echo "  make tekton-run         - Trigger Tekton pipeline run"
	@echo ""
	@echo "Variables:"
	@echo "  REPO_URL=<url>          - GitHub repository URL (default: $(REPO_URL))"

setup-auth:
	@echo "🔐 Setting up GitHub SSH authentication for Tekton..."
	@kubectl config use-context kind-kind || exit 1
	@kubectl config set-context --current --namespace buildkit &2>/dev/null
	@echo "Creating SSH Secret from ~/.ssh/id_ed25519..."
	@kubectl delete secret github-ssh-key  2>/dev/null || true
	@kubectl create secret generic github-ssh-key --from-file=ssh-privatekey=$$HOME/.ssh/id_ed25519
	@kubectl annotate secret github-ssh-key \
		tekton.dev/git-0=github.com
	@echo "Creating ServiceAccount with SSH credentials..."
	@kubectl delete serviceaccount github-bot 2>/dev/null || true
	@kubectl create serviceaccount github-bot
	@kubectl patch serviceaccount github-bot \
		-p '{"secrets":[{"name":"github-ssh-key"}]}'
	@echo "✅ GitHub SSH authentication ready!"
	@echo "PipelineRun already configured to use: serviceAccountName: github-bot"

build:
	@echo "📦 Building hello-world..."
	go build -v -o hello-world main.go
	@echo "✅ Build complete!"

run: build
	@echo "🚀 Running application..."
	./hello-world

test:
	@echo "🧪 Testing HTTP endpoints..."
	@curl -s http://localhost:8080 | head -5
	@echo ""
	@curl -s http://localhost:8080/health | jq .
	@curl -s http://localhost:8080/api/version | jq .

test-github-auth:
	@echo "🔐 Testing GitHub SSH authentication..."
	@echo "Repository: $(REPO_URL)"
	@echo "SSH URL: $(SSH_REPO_URL)"
	@echo ""
	@echo "1️⃣  Checking SSH key..."
	@[ -f $$HOME/.ssh/id_ed25519 ] && echo "✅ SSH key found: $$HOME/.ssh/id_ed25519" || { echo "❌ SSH key not found"; exit 1; }
	@echo ""
	@echo "2️⃣  Checking GitHub SSH connectivity..."
	@ssh -T git@github.com 2>&1 | grep -q "authentication succeeded\|You've successfully authenticated" && echo "✅ GitHub SSH auth successful" || echo "⚠️  Check GitHub SSH setup"
	@echo ""
	@echo "3️⃣  Testing repo clone with SSH..."
	@mkdir -p /tmp/tkn-auth-test && cd /tmp/tkn-auth-test && \
	rm -rf tkn-demo-test && \
	git clone $(SSH_REPO_URL) tkn-demo-test 2>&1 | grep -q "Cloning\|fatal" && \
	if [ -d tkn-demo-test ]; then \
		echo "✅ Successfully cloned repo with SSH"; \
		ls -la tkn-demo-test | head -3; \
		rm -rf tkn-demo-test; \
	else \
		echo "❌ Failed to clone repo"; \
		exit 1; \
	fi
	@echo ""
	@echo "4️⃣  Checking Tekton ServiceAccount..."
	@kubectl get serviceaccount github-bot -n tekton-pipelines &>/dev/null && \
	echo "✅ ServiceAccount 'github-bot' exists" || echo "❌ ServiceAccount not found - run 'make setup-auth'"
	@echo ""
	@echo "5️⃣  Checking GitHub SSH Secret..."
	@kubectl get secret github-ssh-key -n tekton-pipelines &>/dev/null && \
	echo "✅ Secret 'github-ssh-key' exists" || echo "❌ Secret not found - run 'make setup-auth'"
	@echo ""
	@echo "✅ GitHub authentication test complete!"

docker-build:
	@echo "🐳 Building Docker image..."
	docker build -t tkn-demo:latest .
	@echo "✅ Docker image built: tkn-demo:latest"

docker-run: docker-build
	@echo "🚀 Running Docker container..."
	docker run -p 8080:8080 --name tkn-demo tkn-demo:latest || docker rm tkn-demo && docker run -p 8080:8080 --name tkn-demo tkn-demo:latest

docker-clean:
	docker stop tkn-demo 2>/dev/null || true
	docker rm tkn-demo 2>/dev/null || true
	docker rmi tkn-demo:latest 2>/dev/null || true

clean:
	@echo "🧹 Cleaning artifacts..."
	rm -f hello-world
	@echo "✅ Clean complete!"

tekton-apply:
	@echo "📝 Applying Tekton pipeline to cluster..."
	kubectl apply -f tekton/pipeline.yaml
	@echo "✅ Pipeline applied!"

tekton-run:
	@echo "▶️  Triggering Tekton pipeline run..."
	kubectl apply -f tekton/pipelinerun.yaml
	@echo "✅ Pipeline run started!"
	@echo "Monitor with: tkn pr logs -f clone-build-push-run -n tekton-pipelines"
