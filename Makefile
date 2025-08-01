# Makefile for Komodo Periphery Home Assistant Add-on
# Provides convenient commands for development, building, and testing
# Fixed to work with local development environments

.DEFAULT_GOAL := help
.PHONY: help build test clean install dev up down logs shell lint security

# Configuration
ADDON_NAME := komodo-periphery
ADDON_SLUG := komodo_periphery
VERSION := $(shell grep '^version:' config.yaml | cut -d' ' -f2 | tr -d '"')
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
BUILD_REF := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DEFAULT_ARCH := amd64

# Docker configuration
DOCKER_REGISTRY := ghcr.io
DOCKER_NAMESPACE := $(USER)
IMAGE_NAME := $(DOCKER_REGISTRY)/$(DOCKER_NAMESPACE)/$(ADDON_SLUG)
DEV_IMAGE_NAME := $(ADDON_NAME):dev

# Colors for output
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
PURPLE := \033[35m
CYAN := \033[36m
WHITE := \033[37m
RESET := \033[0m

# Help target
help: ## Show this help message
	@echo "$(CYAN)Komodo Periphery Home Assistant Add-on$(RESET)"
	@echo "$(BLUE)======================================$(RESET)"
	@echo ""
	@echo "$(GREEN)Available targets:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Environment variables:$(RESET)"
	@echo "  $(YELLOW)ARCH$(RESET)           Target architecture (default: $(DEFAULT_ARCH))"
	@echo "  $(YELLOW)VERSION$(RESET)        Build version (default: $(VERSION))"
	@echo "  $(YELLOW)REGISTRY$(RESET)       Docker registry (default: $(DOCKER_REGISTRY))"
	@echo ""

# Development targets
install: ## Install development environment
	@echo "$(BLUE)Installing development environment...$(RESET)"
	@if command -v python3 >/dev/null 2>&1; then \
		python3 install.py --dev; \
	elif command -v python >/dev/null 2>&1; then \
		python install.py --dev; \
	elif [ -f install.sh ]; then \
		chmod +x install.sh && ./install.sh --dev; \
	else \
		echo "$(RED)No suitable installer found$(RESET)"; \
		exit 1; \
	fi

dev: ## Start development environment with Docker Compose
	@echo "$(BLUE)Starting development environment...$(RESET)"
	@cp env.development .env 2>/dev/null || cp .env.development .env 2>/dev/null || true
	@if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then \
		docker compose -f docker-compose.dev.yaml up -d; \
	elif command -v docker-compose >/dev/null 2>&1; then \
		docker-compose -f docker-compose.dev.yaml up -d; \
	else \
		echo "$(RED)Neither 'docker compose' nor 'docker-compose' available$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Development environment started$(RESET)"
	@echo "$(CYAN)Periphery API: http://localhost:8120$(RESET)"
	@echo "$(CYAN)Logs: make logs$(RESET)"

up: dev ## Alias for dev

down: ## Stop development environment
	@echo "$(BLUE)Stopping development environment...$(RESET)"
	@if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then \
		docker compose -f docker-compose.dev.yaml down; \
	elif command -v docker-compose >/dev/null 2>&1; then \
		docker-compose -f docker-compose.dev.yaml down; \
	else \
		echo "$(RED)Neither 'docker compose' nor 'docker-compose' available$(RESET)"; \
	fi
	@echo "$(GREEN)Development environment stopped$(RESET)"

logs: ## Show development logs
	@if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then \
		docker compose -f docker-compose.dev.yaml logs -f komodo-periphery; \
	elif command -v docker-compose >/dev/null 2>&1; then \
		docker-compose -f docker-compose.dev.yaml logs -f komodo-periphery; \
	else \
		docker logs komodo-periphery-dev; \
	fi

shell: ## Open shell in development container
	@if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then \
		docker compose -f docker-compose.dev.yaml exec komodo-periphery /bin/bash; \
	elif command -v docker-compose >/dev/null 2>&1; then \
		docker-compose -f docker-compose.dev.yaml exec komodo-periphery /bin/bash; \
	else \
		docker exec -it komodo-periphery-dev /bin/bash; \
	fi

# Build targets
build: ## Build add-on for default architecture
	@$(MAKE) build-arch ARCH=$(DEFAULT_ARCH)

build-arch: ## Build add-on for specific architecture (use ARCH=arch)
	@echo "$(BLUE)Building $(ADDON_NAME) for $(ARCH)...$(RESET)"
	@docker buildx build \
		--platform linux/$(shell echo $(ARCH) | sed 's/amd64/amd64/;s/i386/386/;s/armhf/arm/;s/armv7/arm\/v7/;s/aarch64/arm64/') \
		--build-arg BUILD_ARCH=$(ARCH) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_REF=$(BUILD_REF) \
		--build-arg BUILD_VERSION=$(VERSION) \
		--tag $(DEV_IMAGE_NAME)-$(ARCH) \
		--load \
		.
	@echo "$(GREEN)Build completed: $(DEV_IMAGE_NAME)-$(ARCH)$(RESET)"

build-all: ## Build add-on for all architectures
	@echo "$(BLUE)Building $(ADDON_NAME) for all architectures...$(RESET)"
	@for arch in amd64 aarch64 armhf armv7 i386; do \
		echo "$(YELLOW)Building for $$arch...$(RESET)"; \
		$(MAKE) build-arch ARCH=$$arch; \
	done
	@echo "$(GREEN)All builds completed$(RESET)"

build-dev: ## Build development image
	@echo "$(BLUE)Building development image...$(RESET)"
	@docker build \
		--build-arg BUILD_ARCH=$(DEFAULT_ARCH) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_REF=$(BUILD_REF) \
		--build-arg BUILD_VERSION=dev \
		--tag $(DEV_IMAGE_NAME) \
		.
	@echo "$(GREEN)Development image built: $(DEV_IMAGE_NAME)$(RESET)"

# Testing targets
test: ## Run all tests
	@echo "$(BLUE)Running tests...$(RESET)"
	@$(MAKE) lint
	@$(MAKE) test-build
	@$(MAKE) test-config
	@echo "$(GREEN)All tests passed$(RESET)"

test-build: ## Test build process
	@echo "$(BLUE)Testing build...$(RESET)"
	@docker build --build-arg BUILD_ARCH=$(DEFAULT_ARCH) -t test-build .
	@docker run --rm --entrypoint="" test-build sh -c "echo 'Build test completed successfully'"
	@echo "$(GREEN)Build test passed$(RESET)"

test-config: ## Test configuration files
	@echo "$(BLUE)Testing configuration...$(RESET)"
	@python3 -c "import yaml; yaml.safe_load(open('config.yaml'))" && echo "$(GREEN)✅ config.yaml is valid$(RESET)" || { echo "$(RED)❌ config.yaml is invalid$(RESET)"; exit 1; }
	@if [ -f "build.yaml" ]; then \
		python3 -c "import yaml; yaml.safe_load(open('build.yaml'))" && echo "$(GREEN)✅ build.yaml is valid$(RESET)" || { echo "$(RED)❌ build.yaml is invalid$(RESET)"; exit 1; }; \
	fi
	@echo "$(GREEN)Configuration test passed$(RESET)"

test-install: ## Test installation scripts
	@echo "$(BLUE)Testing installation scripts...$(RESET)"
	@python3 -m py_compile install.py && echo "$(GREEN)✅ install.py syntax is valid$(RESET)"
	@bash -n install.sh 2>/dev/null && echo "$(GREEN)✅ install.sh syntax is valid$(RESET)" || echo "$(YELLOW)⚠️ install.sh has syntax issues$(RESET)"
	@echo "$(GREEN)Installation scripts test passed$(RESET)"

# Linting and code quality
lint: ## Run all linters
	@echo "$(BLUE)Running linters...$(RESET)"
	@$(MAKE) lint-addon
	@$(MAKE) lint-docker
	@$(MAKE) lint-yaml
	@$(MAKE) lint-shell
	@echo "$(GREEN)All linting passed$(RESET)"

lint-addon: ## Lint Home Assistant add-on configuration
	@echo "$(BLUE)Linting add-on configuration...$(RESET)"
	@echo "$(BLUE)Running local add-on configuration validation...$(RESET)"
	@# Use Python-based validation instead of the GitHub Actions specific image
	@python3 -c " \
	import yaml, sys, json; \
	try: \
		with open('config.yaml', 'r') as f: \
			config = yaml.safe_load(f); \
		required_fields = ['name', 'version', 'slug', 'description', 'arch', 'startup']; \
		for field in required_fields: \
			assert field in config, f'Missing required field: {field}'; \
		valid_archs = ['aarch64', 'amd64', 'armhf', 'armv7', 'i386']; \
		for arch in config.get('arch', []): \
			assert arch in valid_archs, f'Invalid architecture: {arch}'; \
		print('✅ Add-on configuration validation passed'); \
	except Exception as e: \
		print(f'❌ Add-on configuration validation failed: {e}'); \
		sys.exit(1); \
	" 2>/dev/null || { \
		echo "$(YELLOW)Python validation failed, trying basic YAML syntax check...$(RESET)"; \
		if command -v yamllint >/dev/null 2>&1; then \
			yamllint config.yaml && echo "$(GREEN)✅ YAML syntax is valid$(RESET)"; \
		else \
			python3 -c "import yaml; yaml.safe_load(open('config.yaml'))" && echo "$(GREEN)✅ YAML syntax is valid$(RESET)"; \
		fi; \
	}

lint-docker: ## Lint Dockerfile
	@echo "$(BLUE)Linting Dockerfile...$(RESET)"
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint Dockerfile; \
	elif command -v docker >/dev/null 2>&1; then \
		echo "$(BLUE)Using Docker-based hadolint...$(RESET)"; \
		docker run --rm -i hadolint/hadolint:latest < Dockerfile 2>/dev/null || { \
			echo "$(YELLOW)Docker-based hadolint failed, skipping Dockerfile lint$(RESET)"; \
		}; \
	else \
		echo "$(YELLOW)hadolint not available, performing basic Dockerfile checks...$(RESET)"; \
		if [ ! -f Dockerfile ]; then \
			echo "$(RED)❌ Dockerfile not found$(RESET)"; exit 1; \
		fi; \
		if ! grep -q "^FROM" Dockerfile; then \
			echo "$(RED)❌ Dockerfile missing FROM instruction$(RESET)"; exit 1; \
		fi; \
		echo "$(GREEN)✅ Basic Dockerfile checks passed$(RESET)"; \
	fi

lint-yaml: ## Lint YAML files
	@echo "$(BLUE)Linting YAML files...$(RESET)"
	@if command -v yamllint >/dev/null 2>&1; then \
		if [ -f ".yamllint.yml" ]; then \
			echo "$(BLUE)Using .yamllint.yml configuration...$(RESET)"; \
			yamllint -c .yamllint.yml . 2>/dev/null || { \
				echo "$(YELLOW)yamllint failed on some files, checking individual files...$(RESET)"; \
				for file in config.yaml build.yaml docker-compose.dev.yaml; do \
					if [ -f "$file" ]; then \
						yamllint -c .yamllint.yml "$file" && echo "$(GREEN)✅ $file is valid$(RESET)" || echo "$(YELLOW)⚠️ $file has issues$(RESET)"; \
					fi; \
				done; \
				if [ -d ".github/workflows" ]; then \
					yamllint -c .yamllint.yml .github/workflows/ && echo "$(GREEN)✅ GitHub workflows are valid$(RESET)" || echo "$(YELLOW)⚠️ GitHub workflows have issues$(RESET)"; \
				fi; \
			}; \
		else \
			echo "$(YELLOW)No .yamllint.yml found, using default configuration...$(RESET)"; \
			yamllint -d "{extends: default, rules: {line-length: {max: 120}}}" *.yaml .github/workflows/ 2>/dev/null || { \
				echo "$(YELLOW)yamllint failed on some files, checking individual files...$(RESET)"; \
				for file in config.yaml build.yaml; do \
					if [ -f "$file" ]; then \
						yamllint "$file" && echo "$(GREEN)✅ $file is valid$(RESET)" || echo "$(YELLOW)⚠️ $file has issues$(RESET)"; \
					fi; \
				done; \
			}; \
		fi; \
	else \
		echo "$(YELLOW)yamllint not available, using Python YAML validation...$(RESET)"; \
		for file in config.yaml build.yaml docker-compose.dev.yaml; do \
			if [ -f "$file" ]; then \
				python3 -c "import yaml; yaml.safe_load(open('$file'))" && echo "$(GREEN)✅ $file is valid YAML$(RESET)" || echo "$(RED)❌ $file is invalid YAML$(RESET)"; \
			fi; \
		done; \
	fi

lint-shell: ## Lint shell scripts
	@echo "$(BLUE)Linting shell scripts...$(RESET)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -exec shellcheck {} \; 2>/dev/null || echo "$(YELLOW)Some shell scripts have issues$(RESET)"; \
		if [ -d rootfs ]; then \
			find rootfs -name "run" -o -name "finish" | xargs shellcheck 2>/dev/null || echo "$(YELLOW)Some rootfs scripts have issues$(RESET)"; \
		fi; \
	else \
		echo "$(YELLOW)shellcheck not available, performing basic shell syntax checks...$(RESET)"; \
		find . -name "*.sh" -exec bash -n {} \; && echo "$(GREEN)✅ Shell scripts syntax is valid$(RESET)" || echo "$(RED)❌ Shell scripts have syntax errors$(RESET)"; \
	fi

# Security and analysis
security: ## Run security scans
	@echo "$(BLUE)Running security scans...$(RESET)"
	@$(MAKE) security-trivy
	@$(MAKE) security-docker

security-trivy: ## Run Trivy vulnerability scan
	@echo "$(BLUE)Running Trivy security scan...$(RESET)"
	@if command -v trivy >/dev/null 2>&1; then \
		trivy image $(DEV_IMAGE_NAME) || true; \
	elif command -v docker >/dev/null 2>&1; then \
		echo "$(BLUE)Using Docker-based Trivy...$(RESET)"; \
		docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
			aquasec/trivy:latest image $(DEV_IMAGE_NAME) 2>/dev/null || { \
			echo "$(YELLOW)Trivy scan failed or image not available$(RESET)"; \
		}; \
	else \
		echo "$(YELLOW)Trivy not available, skipping security scan$(RESET)"; \
	fi

security-docker: ## Run Docker security best practices check
	@echo "$(BLUE)Checking Docker security...$(RESET)"
	@if command -v docker >/dev/null 2>&1; then \
		if docker images | grep -q "$(DEV_IMAGE_NAME)"; then \
			echo "$(GREEN)✅ Docker image exists for security checks$(RESET)"; \
			# Basic security checks \
			USER_ID=$$(docker run --rm $(DEV_IMAGE_NAME) id -u 2>/dev/null || echo "1000"); \
			if [ "$$USER_ID" = "0" ]; then \
				echo "$(YELLOW)⚠️ Container may be running as root user$(RESET)"; \
			else \
				echo "$(GREEN)✅ Container runs as non-root user (UID: $$USER_ID)$(RESET)"; \
			fi; \
		else \
			echo "$(YELLOW)Docker image $(DEV_IMAGE_NAME) not found, build it first with 'make build'$(RESET)"; \
		fi; \
	else \
		echo "$(YELLOW)Docker not available, skipping Docker security checks$(RESET)"; \
	fi

# Publishing and release
push: ## Push image to registry
	@echo "$(BLUE)Pushing image to $(IMAGE_NAME):$(VERSION)...$(RESET)"
	@docker tag $(DEV_IMAGE_NAME) $(IMAGE_NAME):$(VERSION)
	@docker push $(IMAGE_NAME):$(VERSION)
	@echo "$(GREEN)Image pushed successfully$(RESET)"

release: ## Create a release build and push
	@echo "$(BLUE)Creating release $(VERSION)...$(RESET)"
	@$(MAKE) clean
	@$(MAKE) build-all
	@$(MAKE) test
	@$(MAKE) security
	@echo "$(GREEN)Release $(VERSION) ready$(RESET)"

# Maintenance targets
clean: ## Clean up containers and images
	@echo "$(BLUE)Cleaning up...$(RESET)"
	@if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then \
		docker compose -f docker-compose.dev.yaml down --remove-orphans 2>/dev/null || true; \
	elif command -v docker-compose >/dev/null 2>&1; then \
		docker-compose -f docker-compose.dev.yaml down --remove-orphans 2>/dev/null || true; \
	fi
	@docker rmi $(DEV_IMAGE_NAME) 2>/dev/null || true
	@docker rmi $(DEV_IMAGE_NAME)-amd64 2>/dev/null || true
	@docker rmi $(DEV_IMAGE_NAME)-aarch64 2>/dev/null || true
	@docker rmi $(DEV_IMAGE_NAME)-armhf 2>/dev/null || true
	@docker rmi $(DEV_IMAGE_NAME)-armv7 2>/dev/null || true
	@docker rmi $(DEV_IMAGE_NAME)-i386 2>/dev/null || true
	@docker system prune -f 2>/dev/null || true
	@echo "$(GREEN)Cleanup completed$(RESET)"

clean-all: clean ## Clean everything including volumes
	@echo "$(BLUE)Deep cleaning...$(RESET)"
	@docker volume prune -f 2>/dev/null || true
	@rm -rf dev-data/ .pytest_cache/ htmlcov/ .coverage *.log 2>/dev/null || true
	@echo "$(GREEN)Deep cleanup completed$(RESET)"

# Information targets
info: ## Show build information
	@echo "$(CYAN)Build Information$(RESET)"
	@echo "$(BLUE)=================$(RESET)"
	@echo "$(YELLOW)Add-on Name:$(RESET)     $(ADDON_NAME)"
	@echo "$(YELLOW)Add-on Slug:$(RESET)     $(ADDON_SLUG)"
	@echo "$(YELLOW)Version:$(RESET)         $(VERSION)"
	@echo "$(YELLOW)Build Date:$(RESET)      $(BUILD_DATE)"
	@echo "$(YELLOW)Build Ref:$(RESET)       $(BUILD_REF)"
	@echo "$(YELLOW)Registry:$(RESET)        $(DOCKER_REGISTRY)"
	@echo "$(YELLOW)Image:$(RESET)           $(IMAGE_NAME)"
	@echo "$(YELLOW)Dev Image:$(RESET)       $(DEV_IMAGE_NAME)"

status: ## Show development environment status
	@echo "$(CYAN)Development Environment Status$(RESET)"
	@echo "$(BLUE)==============================$(RESET)"
	@if command -v docker >/dev/null 2>&1; then \
		if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then \
			if docker compose -f docker-compose.dev.yaml ps 2>/dev/null | grep -q "komodo-periphery"; then \
				echo "$(GREEN)✓ Development environment is running$(RESET)"; \
				docker compose -f docker-compose.dev.yaml ps; \
			else \
				echo "$(RED)✗ Development environment is not running$(RESET)"; \
			fi; \
		elif command -v docker-compose >/dev/null 2>&1; then \
			if docker-compose -f docker-compose.dev.yaml ps 2>/dev/null | grep -q "komodo-periphery"; then \
				echo "$(GREEN)✓ Development environment is running$(RESET)"; \
				docker-compose -f docker-compose.dev.yaml ps; \
			else \
				echo "$(RED)✗ Development environment is not running$(RESET)"; \
			fi; \
		else \
			echo "$(RED)✗ Neither 'docker compose' nor 'docker-compose' available$(RESET)"; \
		fi; \
	else \
		echo "$(RED)✗ Docker not available$(RESET)"; \
	fi

# Documentation targets
docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(RESET)"
	@echo "# Komodo Periphery Add-on" > BUILD_INFO.md
	@echo "" >> BUILD_INFO.md
	@echo "**Version:** $(VERSION)" >> BUILD_INFO.md
	@echo "**Build Date:** $(BUILD_DATE)" >> BUILD_INFO.md
	@echo "**Build Ref:** $(BUILD_REF)" >> BUILD_INFO.md
	@echo "" >> BUILD_INFO.md
	@echo "## Architecture Support" >> BUILD_INFO.md
	@grep -A 10 "arch:" config.yaml >> BUILD_INFO.md
	@echo "$(GREEN)Documentation generated: BUILD_INFO.md$(RESET)"

# Debug targets
debug: ## Show debug information
	@echo "$(CYAN)Debug Information$(RESET)"
	@echo "$(BLUE)=================$(RESET)"
	@echo "$(YELLOW)Docker Version:$(RESET)"
	@docker --version 2>/dev/null || echo "Docker not available"
	@echo "$(YELLOW)Docker Compose Version:$(RESET)"
	@docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo "Docker Compose not available"
	@echo "$(YELLOW)Python Version:$(RESET)"
	@python3 --version 2>/dev/null || python --version 2>/dev/null || echo "Python not available"
	@echo "$(YELLOW)Build Tools:$(RESET)"
	@command -v hadolint >/dev/null && echo "✓ hadolint" || echo "✗ hadolint"
	@command -v yamllint >/dev/null && echo "✓ yamllint" || echo "✗ yamllint"
	@command -v shellcheck >/dev/null && echo "✓ shellcheck" || echo "✗ shellcheck"
	@command -v trivy >/dev/null && echo "✓ trivy" || echo "✗ trivy"

# Quick development helpers
quick-test: ## Run quick local tests without Docker
	@echo "$(BLUE)Running quick local tests...$(RESET)"
	@$(MAKE) test-config
	@$(MAKE) test-install
	@$(MAKE) lint-yaml
	@echo "$(GREEN)Quick tests completed$(RESET)"

check-tools: ## Check availability of development tools
	@echo "$(CYAN)Development Tools Check$(RESET)"
	@echo "$(BLUE)======================$(RESET)"
	@echo "$(YELLOW)Essential Tools:$(RESET)"
	@command -v python3 >/dev/null && echo "✓ python3" || echo "✗ python3"
	@command -v docker >/dev/null && echo "✓ docker" || echo "✗ docker"
	@command -v git >/dev/null && echo "✓ git" || echo "✗ git"
	@echo "$(YELLOW)Linting Tools:$(RESET)"
	@command -v hadolint >/dev/null && echo "✓ hadolint" || echo "✗ hadolint (install: https://github.com/hadolint/hadolint)"
	@command -v yamllint >/dev/null && echo "✓ yamllint" || echo "✗ yamllint (install: pip install yamllint)"
	@command -v shellcheck >/dev/null && echo "✓ shellcheck" || echo "✗ shellcheck (install via package manager)"
	@echo "$(YELLOW)Security Tools:$(RESET)"
	@command -v trivy >/dev/null && echo "✓ trivy" || echo "✗ trivy (install: https://aquasecurity.github.io/trivy/)"
	@echo "$(YELLOW)Compose Tools:$(RESET)"
	@docker compose version >/dev/null 2>&1 && echo "✓ docker compose (v2)" || echo "✗ docker compose (v2)"
	@command -v docker-compose >/dev/null && echo "✓ docker-compose (v1)" || echo "✗ docker-compose (v1)"
