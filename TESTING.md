# Testing Guide

This document provides comprehensive testing instructions for the Komodo Periphery Home Assistant Add-on.

## Overview

The testing suite includes multiple levels of testing:
- **Unit Tests**: Fast, isolated tests for individual components
- **Integration Tests**: Tests for component interactions and container functionality
- **Security Tests**: Vulnerability scanning and security best practices validation
- **Performance Tests**: Resource usage and startup time validation
- **Installation Tests**: Cross-platform installation script validation

## Quick Start

### Prerequisites
```bash
# Install dependencies
pip install -r .devcontainer/requirements.txt

# Build test image
make build-dev
```

### Run All Tests
```bash
# Run complete test suite
make test

# Run specific test categories
pytest -m "unit"           # Unit tests only
pytest -m "integration"    # Integration tests only
pytest -m "not slow"       # Skip slow tests
```

## Test Structure

```
tests/
├── conftest.py              # Pytest configuration and fixtures
├── test_addon_config.py     # Add-on configuration validation
├── test_integration.py      # Container and integration tests
├── test_installation.py     # Installation script tests
├── test_security.py         # Security and vulnerability tests
└── test_performance.py      # Performance and resource tests
```

## Test Categories

### 1. Unit Tests
Fast, isolated tests that don't require Docker or external dependencies.

```bash
# Run unit tests
pytest -m "unit" -v

# Run with coverage
pytest -m "unit" --cov=. --cov-report=html
```

**Coverage includes:**
- Configuration file validation
- Schema consistency checks
- Translation completeness
- Installation script syntax

### 2. Integration Tests
Tests that validate container functionality and component interactions.

```bash
# Run integration tests (requires Docker)
pytest -m "integration" -v

# Run specific integration test
pytest tests/test_integration.py::TestContainerIntegration::test_container_starts_successfully -v
```

**Coverage includes:**
- Container startup and health checks
- Environment variable handling
- Docker socket access
- Network connectivity
- Configuration file generation

### 3. Security Tests
Comprehensive security validation and vulnerability scanning.

```bash
# Run security tests
pytest -m "security" -v

# Manual security scan
make security
```

**Coverage includes:**
- Vulnerability scanning with Trivy
- Non-root user validation
- Privilege escalation checks
- Secret detection
- Container security best practices

### 4. Performance Tests
Resource usage and performance characteristics validation.

```bash
# Run performance tests
pytest -m "slow" -v

# Manual performance testing
make test-performance
```

**Coverage includes:**
- Container startup time
- Memory usage monitoring
- CPU utilization
- Resource leak detection

### 5. Installation Tests
Cross-platform installation script validation.

```bash
# Test installation scripts
pytest tests/test_installation.py -v

# Manual installation testing
python install.py --help      # Python installer
./install.sh --help          # Bash installer (Linux/macOS)
.\install.ps1 -Help          # PowerShell installer (Windows)
```

## VS Code DevContainer Testing

### Setup
1. Open project in VS Code
2. Install "Dev Containers" extension
3. Reopen in container: `Ctrl+Shift+P` → "Dev Containers: Reopen in Container"

### Available Commands
```bash
# Quick test runner
addon-test

# View container logs
addon-logs

# Access container shell
addon-shell

# Full test suite
make test

# Development environment
make dev
```

### DevContainer Features
- **Pre-configured Environment**: All testing tools installed
- **Docker-in-Docker**: Full Docker support for container testing
- **Integrated Debugging**: VS Code debugging for Python tests
- **Live Reload**: Automatic test execution on file changes
- **Code Coverage**: Integrated coverage reporting

## Test Configuration

### pytest.ini
```ini
[tool:pytest]
testpaths = tests
addopts = --strict-markers --verbose --tb=short
markers =
    slow: marks tests as slow
    integration: marks tests as integration tests
    docker: marks tests as requiring Docker
    network: marks tests as requiring network access
    security: marks tests as security-related
```

### Environment Variables
```bash
# Test configuration
export PYTEST_RUNNING=1
export KOMODO_ADDRESS=https://test.example.com
export KOMODO_API_KEY=test-api-key
export KOMODO_API_SECRET=test-api-secret
export PERIPHERY_LOG_LEVEL=debug
```

## Continuous Integration

### GitHub Actions Workflows

#### 1. CI Pipeline (`.github/workflows/ci.yaml`)
- **Triggers**: Push to main/dev, Pull requests
- **Matrix Testing**: Multiple OS and Python versions
- **Parallel Execution**: Independent test suites run in parallel
- **Artifact Upload**: Test results and coverage reports

#### 2. Builder Pipeline (`.github/workflows/builder.yaml`)
- **Multi-arch Builds**: All supported architectures
- **Security Scanning**: Automated vulnerability detection
- **Release Management**: Automated container registry publishing

#### 3. Test Pipeline (`.github/workflows/test.yaml`)
- **Comprehensive Validation**: All test categories
- **Quality Gates**: Minimum coverage and security requirements
- **Integration Testing**: Full end-to-end validation

### Local CI Testing
```bash
# Install act (GitHub Actions local runner)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | bash

# Run CI locally
act -j lint                    # Run linting job
act -j unit-tests             # Run unit tests
act -j build-tests            # Run build tests
act                           # Run all jobs
```

## Test Data and Fixtures

### Mock Data
- **Mock HA Config**: Simulated Home Assistant configuration
- **Mock Komodo Server**: Test API responses
- **Test Containers**: Pre-configured test environments

### Fixtures
```python
# Available fixtures in conftest.py
@pytest.fixture
def project_root_path():        # Project root directory
def config_data():              # Parsed config.yaml
def build_config_data():        # Parsed build.yaml
def temp_dir():                 # Temporary directory
def mock_ha_config():           # Mock HA configuration
def komodo_periphery_container(): # Test container instance
def docker_client():            # Docker client
```

## Debugging Tests

### VS Code Debugging
1. Set breakpoints in test files
2. Use "Python: Pytest" launch configuration
3. Select specific test to debug
4. Use integrated debugger

### Command Line Debugging
```bash
# Run with debugger
pytest --pdb tests/test_integration.py::test_specific_test

# Verbose output
pytest -vv -s tests/

# Show local variables on failure
pytest --tb=long --showlocals

# Run single test with full output
pytest tests/test_integration.py::TestContainerIntegration::test_container_starts_successfully -vv -s
```

### Container Debugging
```bash
# View container logs during tests
docker logs komodo-periphery-test

# Exec into test container
docker exec -it komodo-periphery-test /bin/bash

# Inspect container configuration
docker inspect komodo-periphery-test
```

## Performance Testing

### Benchmarking
```bash
# Memory usage over time
pytest tests/test_performance.py::test_memory_stability -v

# Startup time measurement
pytest tests/test_performance.py::test_startup_time -v

# Resource monitoring
docker stats komodo-periphery-test
```

### Profiling
```bash
# Profile test execution
pytest --profile tests/

# Memory profiling
pytest --profile-svg tests/
```

## Security Testing

### Vulnerability Scanning
```bash
# Container image scanning
trivy image komodo-periphery:test

# Filesystem scanning
trivy fs .

# Configuration scanning
trivy config .
```

### Security Validation
```bash
# Check for secrets
trufflehog filesystem .

# Dependency vulnerabilities
safety check

# Python security linting
bandit -r .
```

### Compliance Testing
```bash
# Container security benchmarks
docker-bench-security

# CIS benchmarks
kube-bench run --targets node
```

## Troubleshooting

### Common Issues

#### 1. Test Container Won't Start
```bash
# Check Docker status
docker info

# Check image exists
docker images | grep komodo-periphery

# Check container logs
docker logs komodo-periphery-test

# Rebuild test image
make clean && make build-dev
```

#### 2. Integration Tests Failing
```bash
# Check Docker socket permissions
ls -la /var/run/docker.sock

# Verify container networking
docker network ls

# Test manual container run
docker run --rm -it komodo-periphery:test /bin/bash
```

#### 3. Permission Errors
```bash
# Fix file permissions
chmod +x install.sh
sudo chown -R $USER:$USER .

# Docker group membership
sudo usermod -aG docker $USER
# Log out and back in
```

#### 4. Memory/Resource Issues
```bash
# Clean up Docker resources
docker system prune -f
docker volume prune -f

# Check available resources
free -h
df -h
```

### Test Environment Cleanup
```bash
# Clean all test artifacts
make clean-all

# Remove test containers
docker rm -f $(docker ps -aq --filter "name=test")

# Remove test images
docker rmi $(docker images -q --filter "reference=*test*")

# Reset test environment
rm -rf .pytest_cache htmlcov .coverage
```

## Best Practices

### Writing Tests
1. **Use descriptive test names**: `test_container_starts_with_valid_config`
2. **Follow AAA pattern**: Arrange, Act, Assert
3. **Use appropriate markers**: `@pytest.mark.integration`
4. **Mock external dependencies**: Use fixtures for isolation
5. **Test both positive and negative cases**

### Test Organization
1. **Group related tests**: Use test classes
2. **Use fixtures for setup**: Reusable test data and objects
3. **Keep tests independent**: No shared state between tests
4. **Use parametrization**: Test multiple scenarios efficiently

### Performance Considerations
1. **Use appropriate markers**: Skip slow tests in development
2. **Parallelize when possible**: Use pytest-xdist
3. **Clean up resources**: Proper fixture teardown
4. **Monitor test execution time**: Identify slow tests

### CI/CD Integration
1. **Fail fast**: Run quick tests first
2. **Parallel execution**: Use matrix strategies
3. **Artifact preservation**: Save test results and coverage
4. **Quality gates**: Enforce minimum coverage and security standards

## Test Reports and Coverage

### Coverage Reports
```bash
# Generate HTML coverage report
pytest --cov=. --cov-report=html

# View coverage report
open htmlcov/index.html  # macOS
xdg-open htmlcov/index.html  # Linux
```

### Test Results
```bash
# Generate JUnit XML report
pytest --junit-xml=test-results.xml

# Generate detailed test report
pytest --html=report.html --self-contained-html
```

### Continuous Monitoring
- **Codecov Integration**: Automatic coverage tracking
- **GitHub Security Advisories**: Vulnerability alerts
- **Dependabot**: Automated dependency updates
- **Test Result Trends**: Historical test performance tracking

## Advanced Testing

### Custom Test Scenarios
```python
# Custom test scenarios
@pytest.mark.parametrize("config_scenario", [
    "minimal_config",
    "full_config", 
    "ssl_disabled",
    "debug_mode"
])
def test_container_with_config(config_scenario, komodo_periphery_container):
    # Test different configuration scenarios
    pass
```

### Load Testing
```bash
# Install load testing tools
pip install locust

# Run load tests against test container
locust -f tests/load_test.py --host=http://localhost:8120
```

### Chaos Testing
```bash
# Install chaos engineering tools
pip install chaostoolkit

# Run chaos experiments
chaos run tests/chaos_experiments.yaml
```

## Documentation and Reporting

### Test Documentation
- **Test Plans**: Document test strategies and scenarios
- **Test Cases**: Detailed test case specifications
- **Coverage Reports**: Track code coverage metrics
- **Security Reports**: Document security test results

### Automated Reporting
- **GitHub Actions Summary**: Automated test result summaries
- **Slack/Discord Notifications**: Real-time test status updates
- **Email Reports**: Scheduled test result reports
- **Dashboard Integration**: Test metrics visualization

---

## Support and Resources

- **Home Assistant Developer Documentation**: https://developers.home-assistant.io/docs/add-ons/testing
- **Pytest Documentation**: https://docs.pytest.org/
- **Docker Testing Best Practices**: https://docs.docker.com/develop/dev-best-practices/
- **GitHub Actions Testing**: https://docs.github.com/en/actions/automating-builds-and-tests

For additional help, check the project's GitHub issues or ask in the Home Assistant Community forum.