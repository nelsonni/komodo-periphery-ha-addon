"""
Pytest configuration and fixtures for Komodo Periphery Add-on testing.
Updated to support both basic and integration tests.
"""

import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, Generator

import docker
import pytest
import yaml

# Add project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Test configuration
TEST_TIMEOUT = 60
ADDON_NAME = "komodo-periphery"
ADDON_SLUG = "komodo_periphery"


@pytest.fixture(scope="session")
def docker_client() -> docker.DockerClient:
    """Provide Docker client for tests."""
    try:
        client = docker.from_env()
        # Test connectivity
        client.ping()
        return client
    except Exception as e:
        pytest.skip(f"Docker not available: {e}")


@pytest.fixture(scope="session")
def project_root_path() -> Path:
    """Provide project root path."""
    return project_root


@pytest.fixture(scope="session")
def config_data() -> Dict[str, Any]:
    """Load and provide add-on configuration data."""
    config_path = project_root / "config.yaml"
    if not config_path.exists():
        pytest.skip("config.yaml not found")

    with open(config_path, "r") as f:
        return yaml.safe_load(f)


@pytest.fixture(scope="session")
def build_config_data() -> Dict[str, Any]:
    """Load and provide build configuration data."""
    build_config_path = project_root / "build.yaml"
    if not build_config_path.exists():
        pytest.skip("build.yaml not found")

    with open(build_config_path, "r") as f:
        return yaml.safe_load(f)


@pytest.fixture
def temp_dir() -> Generator[Path, None, None]:
    """Provide temporary directory for tests."""
    temp_path = Path(tempfile.mkdtemp())
    try:
        yield temp_path
    finally:
        shutil.rmtree(temp_path, ignore_errors=True)


@pytest.fixture
def mock_addon_config(temp_dir: Path) -> Path:
    """Create mock add-on configuration for testing."""
    config_content = {
        "komodo_address": "https://test.example.com",
        "komodo_api_key": "test-api-key",
        "komodo_api_secret": "test-api-secret",
        "log_level": "debug",
        "stats_polling_rate": "5-sec",
        "container_stats_polling_rate": "1-min",
        "ssl_enabled": True,
        "monitor_homeassistant": True,
    }

    config_file = temp_dir / "addon_config.yaml"
    with open(config_file, "w") as f:
        yaml.dump(config_content, f)

    return config_file


@pytest.fixture
def mock_periphery_config(temp_dir: Path) -> Path:
    """Create mock Komodo Periphery configuration."""
    config_content = """
# Test Komodo Periphery Configuration
port = 8120
stats_polling_rate = "5-sec"
container_stats_polling_rate = "1-min"
ssl_enabled = true

[logging]
level = "debug"
pretty = false
"""
    config_file = temp_dir / "periphery.config.toml"
    config_file.write_text(config_content)
    return config_file


@pytest.fixture(scope="session")
def test_image_name() -> str:
    """Provide test Docker image name."""
    return f"{ADDON_NAME}:test"


@pytest.fixture(scope="session")
def build_test_image(
    docker_client: docker.DockerClient, test_image_name: str
) -> Generator[str, None, None]:
    """Build test Docker image if Dockerfile exists."""
    dockerfile_path = project_root / "Dockerfile"

    if not dockerfile_path.exists():
        # If no Dockerfile, skip building and use Alpine for tests
        yield "alpine:latest"
        return

    try:
        print(f"Building test image: {test_image_name}")

        # Build the image
        image, logs = docker_client.images.build(
            path=str(project_root),
            tag=test_image_name,
            dockerfile="Dockerfile",
            buildargs={
                "BUILD_ARCH": "amd64",
                "BUILD_DATE": "2025-01-01T00:00:00Z",
                "BUILD_REF": "test",
                "BUILD_VERSION": "test",
            },
            rm=True,
        )

        # Print build logs for debugging (only errors/warnings)
        for log in logs:
            if "stream" in log:
                line = log["stream"].strip()
                if line and ("error" in line.lower() or "warning" in line.lower()):
                    print(line)

        yield test_image_name

    except Exception as e:
        print(f"Failed to build test image: {e}")
        # Fallback to Alpine
        yield "alpine:latest"
    finally:
        # Cleanup: Remove test image
        try:
            docker_client.images.remove(test_image_name, force=True)
            print(f"Cleaned up test image: {test_image_name}")
        except:
            pass


@pytest.fixture
def clean_docker_environment(docker_client: docker.DockerClient):
    """Ensure clean Docker environment for tests."""
    # Clean up any existing test containers
    try:
        containers = docker_client.containers.list(
            all=True, filters={"name": "test"})
        for container in containers:
            try:
                container.remove(force=True)
            except:
                pass
    except:
        pass

    yield

    # Cleanup after test
    try:
        containers = docker_client.containers.list(
            all=True, filters={"name": "test"})
        for container in containers:
            try:
                container.remove(force=True)
            except:
                pass
    except:
        pass


@pytest.fixture(autouse=True)
def setup_test_environment(monkeypatch):
    """Set up test environment variables."""
    test_env = {
        "PYTEST_RUNNING": "1",
        "KOMODO_ADDRESS": "https://test.example.com",
        "KOMODO_API_KEY": "test-api-key",
        "KOMODO_API_SECRET": "test-api-secret",
        "PERIPHERY_LOG_LEVEL": "debug",
        "PERIPHERY_SSL_ENABLED": "false",  # Disable SSL for testing
        "PERIPHERY_STATS_POLLING_RATE": "10-sec",
        "PERIPHERY_CONTAINER_STATS_POLLING_RATE": "1-min",
    }

    for key, value in test_env.items():
        monkeypatch.setenv(key, value)


# Legacy fixtures for compatibility with existing integration tests
@pytest.fixture
def komodo_periphery_container(
    build_test_image: str, docker_client: docker.DockerClient
):
    """
    Legacy fixture for compatibility with old integration tests.
    Creates a simple container wrapper.
    """

    class SimpleContainerWrapper:
        def __init__(self, image_name, client):
            self.image_name = image_name
            self.client = client
            self.container = None

        def start_container(self):
            """Start a simple test container."""
            if not self.container:
                self.container = self.client.containers.run(
                    self.image_name,
                    command=["sh", "-c",
                             'echo "Test container started" && sleep 30'],
                    detach=True,
                    remove=False,
                    environment={
                        "KOMODO_ADDRESS": "https://test.example.com",
                        "KOMODO_API_KEY": "test-key",
                        "KOMODO_API_SECRET": "test-secret",
                    },
                    ports={"8120/tcp": None},
                )
            return self.container

        def get_container_host_ip(self):
            """Get container host IP."""
            return "127.0.0.1"

        def get_exposed_port(self, port):
            """Get exposed port."""
            if not self.container:
                self.start_container()
            try:
                return self.container.ports.get(f"{port}/tcp", [{}])[0].get(
                    "HostPort", port
                )
            except:
                return port

        def get_logs(self):
            """Get container logs."""
            if not self.container:
                self.start_container()
            return self.container.logs()

        def get_docker_client(self):
            """Get Docker client."""
            return self.client

        def get_wrapped_container(self):
            """Get the actual container object."""
            if not self.container:
                self.start_container()
            return self.container

        def exec_run(self, command, timeout=30):
            """Execute command in container."""
            if not self.container:
                self.start_container()
            try:
                result = self.container.exec_run(command, timeout=timeout)
                return result.exit_code, result.output
            except Exception as e:
                return 1, str(e).encode()

        def cleanup(self):
            """Clean up container."""
            if self.container:
                try:
                    self.container.remove(force=True)
                except:
                    pass
                self.container = None

    wrapper = SimpleContainerWrapper(build_test_image, docker_client)
    yield wrapper
    wrapper.cleanup()


def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "integration: mark test as integration test")
    config.addinivalue_line("markers", "slow: mark test as slow running")
    config.addinivalue_line("markers", "docker: mark test as requiring Docker")
    config.addinivalue_line(
        "markers", "network: mark test as requiring network access")
    config.addinivalue_line("markers", "unit: mark test as unit test")


def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers based on test names."""
    for item in items:
        # Add integration marker to integration tests
        if "integration" in item.nodeid:
            item.add_marker(pytest.mark.integration)

        # Add docker marker to docker-related tests
        if "docker" in item.nodeid or "container" in item.nodeid:
            item.add_marker(pytest.mark.docker)

        # Add network marker to network tests
        if "network" in item.nodeid or "api" in item.nodeid:
            item.add_marker(pytest.mark.network)

        # Add slow marker to potentially slow tests
        if any(
            keyword in item.nodeid
            for keyword in ["build", "security", "integration", "performance"]
        ):
            item.add_marker(pytest.mark.slow)

        # Add unit marker to non-integration tests
        if "integration" not in item.nodeid and "docker" not in item.nodeid:
            item.add_marker(pytest.mark.unit)


@pytest.fixture(scope="session", autouse=True)
def cleanup_test_environment():
    """Clean up test environment after session."""
    yield

    # Cleanup Docker resources if available
    try:
        client = docker.from_env()

        # Remove test containers
        containers = client.containers.list(all=True)
        for container in containers:
            if container.name and "test" in container.name.lower():
                try:
                    container.remove(force=True)
                except Exception:
                    pass

        # Remove test images with test tags
        images = client.images.list()
        for image in images:
            for tag in image.tags:
                if "test" in tag.lower():
                    try:
                        client.images.remove(image.id, force=True)
                    except Exception:
                        pass

    except Exception:
        # Docker not available or other error - ignore
        pass


# Test helpers
def wait_for_condition(condition_func, timeout=30, interval=1):
    """Wait for a condition to be true."""
    import time

    start_time = time.time()
    while time.time() - start_time < timeout:
        if condition_func():
            return True
        time.sleep(interval)
    return False


def get_container_ip(container):
    """Get container IP address."""
    try:
        container.reload()
        return container.attrs["NetworkSettings"]["IPAddress"]
    except:
        return None
