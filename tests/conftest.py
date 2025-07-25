"""
Pytest configuration and fixtures for Komodo Periphery Add-on testing.
"""

import os
import sys
import tempfile
import shutil
from pathlib import Path
from typing import Generator, Dict, Any
import pytest
import docker
import yaml
import json
from testcontainers.core.container import DockerContainer
from testcontainers.core.waiting_strategies import WaitingFor

# Add project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Test configuration
TEST_TIMEOUT = 60
ADDON_NAME = "komodo-periphery"
ADDON_SLUG = "komodo_periphery"


class KomodoPeripheryContainer(DockerContainer):
    """Custom container class for Komodo Periphery testing."""
    
    def __init__(self, image: str = "komodo-periphery:test", **kwargs):
        super().__init__(image, **kwargs)
        self.with_exposed_ports(8120)
        self.with_env("KOMODO_ADDRESS", "https://mock.example.com")
        self.with_env("KOMODO_API_KEY", "test-key")
        self.with_env("KOMODO_API_SECRET", "test-secret")
        self.with_env("PERIPHERY_LOG_LEVEL", "debug")


@pytest.fixture(scope="session")
def docker_client() -> docker.DockerClient:
    """Provide Docker client for tests."""
    return docker.from_env()


@pytest.fixture(scope="session")
def project_root_path() -> Path:
    """Provide project root path."""
    return project_root


@pytest.fixture(scope="session")
def config_data() -> Dict[str, Any]:
    """Load and provide add-on configuration data."""
    config_path = project_root / "config.yaml"
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)


@pytest.fixture(scope="session")
def build_config_data() -> Dict[str, Any]:
    """Load and provide build configuration data."""
    build_config_path = project_root / "build.yaml"
    with open(build_config_path, 'r') as f:
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
def mock_ha_config(temp_dir: Path) -> Path:
    """Create mock Home Assistant configuration."""
    ha_config = temp_dir / "configuration.yaml"
    ha_config.write_text("""
homeassistant:
  name: Test Home
  latitude: 32.87336
  longitude: 117.22743
  elevation: 430
  unit_system: metric
  time_zone: America/Los_Angeles

http:
  server_port: 8123

logger:
  default: info
""")
    return temp_dir


@pytest.fixture
def mock_addon_config(temp_dir: Path, config_data: Dict[str, Any]) -> Path:
    """Create mock add-on configuration for testing."""
    addon_config = temp_dir / "addon_config.json"
    
    test_config = {
        "komodo_address": "https://test.example.com",
        "komodo_api_key": "test-api-key",
        "komodo_api_secret": "test-api-secret",
        "log_level": "debug",
        "stats_polling_rate": "5-sec",
        "container_stats_polling_rate": "1-min",
        "ssl_enabled": True,
        "monitor_homeassistant": True
    }
    
    with open(addon_config, 'w') as f:
        json.dump(test_config, f, indent=2)
    
    return addon_config


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
def build_test_image(docker_client: docker.DockerClient, test_image_name: str) -> str:
    """Build test Docker image."""
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
            "BUILD_VERSION": "test"
        },
        rm=True
    )
    
    # Print build logs for debugging
    for log in logs:
        if 'stream' in log:
            print(log['stream'].strip())
    
    yield test_image_name
    
    # Cleanup: Remove test image
    try:
        docker_client.images.remove(test_image_name, force=True)
        print(f"Cleaned up test image: {test_image_name}")
    except docker.errors.ImageNotFound:
        pass


@pytest.fixture
def komodo_periphery_container(build_test_image: str) -> Generator[KomodoPeripheryContainer, None, None]:
    """Provide Komodo Periphery container for testing."""
    with KomodoPeripheryContainer(build_test_image) as container:
        container.with_waiting_for(
            WaitingFor.http_response(container, port=8120, path="/health", timeout=30)
        )
        yield container


@pytest.fixture
def container_logs():
    """Capture and provide container logs for debugging."""
    logs = []
    
    def capture_logs(container):
        try:
            logs.extend(container.get_logs())
        except Exception as e:
            logs.append(f"Error capturing logs: {e}")
    
    yield capture_logs
    
    # Print logs if test failed
    if logs:
        print("\n=== Container Logs ===")
        for log in logs:
            print(log)


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
        "PERIPHERY_CONTAINER_STATS_POLLING_RATE": "1-min"
    }
    
    for key, value in test_env.items():
        monkeypatch.setenv(key, value)


@pytest.fixture
def mock_docker_client():
    """Provide mock Docker client for testing."""
    class MockDockerClient:
        def __init__(self):
            self.containers = MockContainerManager()
            self.images = MockImageManager()
        
        def version(self):
            return {"Version": "20.10.0"}
    
    class MockContainerManager:
        def list(self, all=False):
            return [
                MockContainer("test-container-1", "running"),
                MockContainer("test-container-2", "stopped")
            ]
    
    class MockImageManager:
        def list(self):
            return [MockImage("test-image:latest")]
    
    class MockContainer:
        def __init__(self, name, status):
            self.name = name
            self.status = status
            self.id = f"mock-{name}"
        
        def stats(self, stream=False):
            return {
                "memory_stats": {"usage": 1024000, "limit": 2048000},
                "cpu_stats": {"cpu_usage": {"total_usage": 100000}}
            }
    
    class MockImage:
        def __init__(self, tag):
            self.tags = [tag]
            self.id = "mock-image-id"
    
    return MockDockerClient()


def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "integration: mark test as integration test"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )
    config.addinivalue_line(
        "markers", "docker: mark test as requiring Docker"
    )
    config.addinivalue_line(
        "markers", "network: mark test as requiring network access"
    )


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
        if any(keyword in item.nodeid for keyword in ["build", "security", "integration"]):
            item.add_marker(pytest.mark.slow)


@pytest.fixture(scope="session", autouse=True)
def cleanup_test_containers():
    """Clean up any test containers after test session."""
    yield
    
    # Cleanup Docker resources
    try:
        client = docker.from_env()
        # Remove test containers
        for container in client.containers.list(all=True):
            if container.name and "test" in container.name.lower():
                try:
                    container.remove(force=True)
                except Exception:
                    pass
        
        # Remove test images
        for image in client.images.list():
            for tag in image.tags:
                if "test" in tag.lower():
                    try:
                        client.images.remove(image.id, force=True)
                    except Exception:
                        pass
    except Exception:
        pass  # Ignore cleanup errors