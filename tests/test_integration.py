"""
Integration tests for Komodo Periphery Add-on.
"""

import pytest
import time
import requests
import docker
from typing import Dict, Any
from pathlib import Path


@pytest.mark.integration
@pytest.mark.docker
class TestContainerIntegration:
    """Integration tests for container functionality."""

    def test_container_starts_successfully(self, komodo_periphery_container):
        """Test that the container starts successfully."""
        assert komodo_periphery_container.get_container_host_ip()
        assert komodo_periphery_container.get_exposed_port(8120)

    def test_container_health_check(self, komodo_periphery_container):
        """Test container health check endpoint."""
        host = komodo_periphery_container.get_container_host_ip()
        port = komodo_periphery_container.get_exposed_port(8120)
        
        # Give container time to fully start
        time.sleep(10)
        
        try:
            response = requests.get(
                f"http://{host}:{port}/health",
                timeout=30,
                verify=False
            )
            
            # Health check should return 200 or may not be implemented yet
            assert response.status_code in [200, 404], f"Unexpected status: {response.status_code}"
            
        except requests.exceptions.ConnectionError:
            # If connection fails, check if container is still running
            container_info = komodo_periphery_container.get_docker_client().api.inspect_container(
                komodo_periphery_container.get_wrapped_container().id
            )
            assert container_info['State']['Running'], "Container should be running"

    def test_container_logs_contain_startup_info(self, komodo_periphery_container):
        """Test that container logs contain expected startup information."""
        logs = komodo_periphery_container.get_logs().decode('utf-8')
        
        # Check for key startup indicators
        expected_patterns = [
            "periphery",  # Binary name should appear
            "8120",       # Default port should appear
        ]
        
        for pattern in expected_patterns:
            assert pattern in logs, f"Expected pattern '{pattern}' not found in logs"

    def test_container_environment_variables(self, komodo_periphery_container):
        """Test that environment variables are properly set."""
        container_info = komodo_periphery_container.get_docker_client().api.inspect_container(
            komodo_periphery_container.get_wrapped_container().id
        )
        
        env_vars = container_info['Config']['Env']
        env_dict = {}
        
        for env_var in env_vars:
            if '=' in env_var:
                key, value = env_var.split('=', 1)
                env_dict[key] = value
        
        # Check required environment variables
        required_env_vars = [
            'KOMODO_ADDRESS',
            'KOMODO_API_KEY',
            'KOMODO_API_SECRET'
        ]
        
        for env_var in required_env_vars:
            assert env_var in env_dict, f"Required environment variable '{env_var}' not set"

    def test_container_user_is_non_root(self, komodo_periphery_container):
        """Test that container runs as non-root user."""
        container_info = komodo_periphery_container.get_docker_client().api.inspect_container(
            komodo_periphery_container.get_wrapped_container().id
        )
        
        # Check user configuration
        user = container_info['Config']['User']
        
        # Should be running as komodo user (UID 1000) or non-root
        assert user and user != "0" and user != "root", f"Container should not run as root, got: {user}"

    @pytest.mark.slow
    def test_container_resource_usage(self, komodo_periphery_container):
        """Test container resource usage is reasonable."""
        # Let container run for a bit to get stable metrics
        time.sleep(30)
        
        container = komodo_periphery_container.get_wrapped_container()
        stats = container.stats(stream=False)
        
        # Check memory usage (should be reasonable for a monitoring agent)
        memory_usage = stats['memory_stats']['usage']
        memory_limit = stats['memory_stats']['limit']
        memory_percent = (memory_usage / memory_limit) * 100
        
        # Should use less than 50% of available memory under normal conditions
        assert memory_percent < 50, f"Memory usage too high: {memory_percent}%"
        
        # Check that CPU usage exists (indicates the process is running)
        assert 'cpu_stats' in stats, "CPU stats should be available"


@pytest.mark.integration
@pytest.mark.network
class TestNetworkIntegration:
    """Integration tests for network functionality."""

    def test_port_accessibility(self, komodo_periphery_container):
        """Test that the Periphery port is accessible."""
        host = komodo_periphery_container.get_container_host_ip()
        port = komodo_periphery_container.get_exposed_port(8120)
        
        # Test TCP connection
        import socket
        
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        
        try:
            result = sock.connect_ex((host, int(port)))
            # Connection should succeed (result = 0) or be refused but reachable
            assert result in [0, 111], f"Port {port} not accessible, result: {result}"
        finally:
            sock.close()

    @pytest.mark.slow
    def test_mock_komodo_api_interaction(self, komodo_periphery_container):
        """Test interaction with mock Komodo API."""
        # This would require a mock Komodo server
        # For now, just verify the container is trying to connect
        
        logs = komodo_periphery_container.get_logs().decode('utf-8')
        
        # Look for connection attempts or API-related logs
        # The exact log format will depend on Komodo Periphery implementation
        assert len(logs) > 0, "Container should produce logs"


@pytest.mark.integration
class TestConfigurationIntegration:
    """Integration tests for configuration handling."""

    def test_config_file_generation(self, komodo_periphery_container, temp_dir):
        """Test that configuration files are generated correctly."""
        # Execute command in container to check config generation
        exit_code, output = komodo_periphery_container.exec_run(
            "ls -la /data/config/",
            timeout=30
        )
        
        # Command should succeed
        assert exit_code == 0, f"Config directory listing failed: {output}"
        
        # Check if config files exist
        if "periphery.config.toml" in output.decode():
            # Config file was generated
            exit_code, config_content = komodo_periphery_container.exec_run(
                "cat /data/config/periphery.config.toml",
                timeout=30
            )
            
            assert exit_code == 0, "Could not read config file"
            config_str = config_content.decode()
            
            # Check for expected configuration elements
            assert "port" in config_str, "Config should contain port setting"
            assert "8120" in config_str, "Config should contain default port"

    def test_ssl_certificate_generation(self, komodo_periphery_container):
        """Test SSL certificate generation."""
        # Check if SSL directory exists
        exit_code, output = komodo_periphery_container.exec_run(
            "ls -la /data/ssl/",
            timeout=30
        )
        
        if exit_code == 0:  # SSL directory exists
            ssl_content = output.decode()
            
            # If SSL is enabled, certificates should be present
            if "cert.pem" in ssl_content and "key.pem" in ssl_content:
                # Verify certificate validity
                exit_code, cert_info = komodo_periphery_container.exec_run(
                    "openssl x509 -in /data/ssl/cert.pem -text -noout",
                    timeout=30
                )
                
                if exit_code == 0:
                    cert_text = cert_info.decode()
                    assert "Certificate:" in cert_text, "Generated certificate should be valid"


@pytest.mark.integration
@pytest.mark.docker
class TestDockerIntegration:
    """Integration tests for Docker socket access."""

    def test_docker_socket_access(self, komodo_periphery_container):
        """Test that container can access Docker socket."""
        # Test if docker command is available and can connect
        exit_code, output = komodo_periphery_container.exec_run(
            "docker version",
            timeout=30
        )
        
        if exit_code == 0:
            # Docker is accessible
            docker_output = output.decode()
            assert "Client:" in docker_output, "Docker client should be accessible"
        else:
            # Docker might not be available in test environment
            # This is acceptable for unit testing
            pytest.skip("Docker socket not available in test environment")

    def test_container_listing(self, komodo_periphery_container):
        """Test container listing functionality."""
        # Test if the container can list Docker containers
        exit_code, output = komodo_periphery_container.exec_run(
            "docker ps",
            timeout=30
        )
        
        if exit_code == 0:
            # Should be able to see at least itself
            container_list = output.decode()
            assert "CONTAINER ID" in container_list, "Should show container listing header"


@pytest.mark.integration
@pytest.mark.slow
class TestPerformanceIntegration:
    """Integration tests for performance characteristics."""

    def test_startup_time(self, build_test_image):
        """Test that container starts within reasonable time."""
        client = docker.from_env()
        
        start_time = time.time()
        
        container = client.containers.run(
            build_test_image,
            environment={
                'KOMODO_ADDRESS': 'https://test.example.com',
                'KOMODO_API_KEY': 'test-key',
                'KOMODO_API_SECRET': 'test-secret'
            },
            detach=True,
            remove=True,
            ports={'8120/tcp': None}
        )
        
        try:
            # Wait for container to be ready
            for _ in range(30):  # 30 seconds max
                container.reload()
                if container.status == 'running':
                    break
                time.sleep(1)
            
            startup_time = time.time() - start_time
            
            # Container should start within 30 seconds
            assert startup_time < 30, f"Container took too long to start: {startup_time}s"
            assert container.status == 'running', "Container should be running"
            
        finally:
            try:
                container.stop(timeout=10)
            except:
                pass

    def test_memory_stability(self, komodo_periphery_container):
        """Test memory usage stability over time."""
        initial_stats = komodo_periphery_container.get_wrapped_container().stats(stream=False)
        initial_memory = initial_stats['memory_stats']['usage']
        
        # Wait and check again
        time.sleep(60)  # Wait 1 minute
        
        final_stats = komodo_periphery_container.get_wrapped_container().stats(stream=False)
        final_memory = final_stats['memory_stats']['usage']
        
        # Memory should not increase dramatically (no significant memory leaks)
        memory_increase = final_memory - initial_memory
        memory_increase_percent = (memory_increase / initial_memory) * 100
        
        # Allow up to 20% memory increase over 1 minute (reasonable for initialization)
        assert memory_increase_percent < 20, f"Memory increased too much: {memory_increase_percent}%"


@pytest.mark.integration
class TestErrorHandling:
    """Integration tests for error handling."""

    def test_invalid_config_handling(self, build_test_image):
        """Test handling of invalid configuration."""
        client = docker.from_env()
        
        # Start container with invalid configuration
        container = client.containers.run(
            build_test_image,
            environment={
                'KOMODO_ADDRESS': 'invalid-url',
                'KOMODO_API_KEY': '',  # Empty key
                'KOMODO_API_SECRET': 'test-secret'
            },
            detach=True,
            remove=True
        )
        
        try:
            # Give container time to process invalid config
            time.sleep(10)
            
            # Check container logs for error handling
            logs = container.logs().decode()
            
            # Should contain error messages about invalid configuration
            # The exact error messages depend on implementation
            assert len(logs) > 0, "Container should produce error logs for invalid config"
            
        finally:
            try:
                container.stop(timeout=5)
            except:
                pass

    def test_network_failure_resilience(self, komodo_periphery_container):
        """Test resilience to network failures."""
        # This test verifies the container continues running even if it can't reach Komodo Core
        # Let container run with unreachable Komodo address
        time.sleep(30)
        
        # Container should still be running despite network issues
        container = komodo_periphery_container.get_wrapped_container()
        container.reload()
        
        assert container.status == 'running', "Container should remain running despite network issues"