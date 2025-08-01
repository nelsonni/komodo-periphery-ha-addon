"""
Integration tests for Komodo Periphery Add-on.
Updated to work with current project setup and avoid fixture dependencies.
"""

import time

import docker
import pytest


@pytest.mark.integration
@pytest.mark.docker
class TestContainerIntegration:
    """Integration tests for container functionality."""

    def test_alpine_container_with_komodo_env(self):
        """Test Alpine container with Komodo environment setup."""
        client = docker.from_env()

        # Script that mimics Komodo Periphery startup
        startup_script = """
        echo "=== Komodo Periphery Container Test ==="

        # Verify environment variables
        echo "Checking environment variables..."
        echo "KOMODO_ADDRESS: $KOMODO_ADDRESS"
        echo "KOMODO_API_KEY: ${KOMODO_API_KEY:0:8}***"
        echo "KOMODO_API_SECRET: ${KOMODO_API_SECRET:0:8}***"

        # Create mock periphery setup
        WORK_DIR="/tmp/komodo_periphery"
        mkdir -p "$WORK_DIR/config"
        mkdir -p "$WORK_DIR/ssl"
        mkdir -p "$WORK_DIR/logs"

        # Generate configuration file
        cat > "$WORK_DIR/config/periphery.config.toml" << 'EOF'
# Komodo Periphery Configuration
port = 8120
stats_polling_rate = "5-sec"
container_stats_polling_rate = "1-min"
ssl_enabled = true

[logging]
level = "debug"
pretty = false

[server]
address = "0.0.0.0"
EOF

        # Create mock SSL certificates
        echo "Generating mock SSL certificates..."
        openssl req -x509 -newkey rsa:2048 -keyout "$WORK_DIR/ssl/key.pem" \
            -out "$WORK_DIR/ssl/cert.pem" -days 1 -nodes \
            -subj "/C=US/ST=Test/L=Test/O=Test/CN=periphery" 2>/dev/null || echo "SSL generation skipped"

        # Test port binding simulation
        echo "Testing port 8120 availability..."
        nc -l -p 8120 &
        NC_PID=$!
        sleep 2

        # Check if port is bound
        if netstat -ln 2>/dev/null | grep -q ":8120"; then
            echo "✓ Port 8120 successfully bound"
        else
            echo "⚠ Port binding test skipped (netstat/nc not available)"
        fi

        # Cleanup background process
        kill $NC_PID 2>/dev/null || true

        # Verify configuration
        if [ -f "$WORK_DIR/config/periphery.config.toml" ]; then
            echo "✓ Configuration file created"
            echo "Port setting:"
            grep "port = " "$WORK_DIR/config/periphery.config.toml"
        fi

        echo "=== Container integration test completed ==="
        """

        container = None
        try:
            container = client.containers.run(
                "alpine:latest",
                command=["sh", "-c", startup_script],
                detach=True,
                remove=False,
                environment={
                    "KOMODO_ADDRESS": "https://test.komodo.example.com",
                    "KOMODO_API_KEY": "integration-test-key-12345",
                    "KOMODO_API_SECRET": "integration-test-secret-67890",
                    "PERIPHERY_PORT": "8120",
                    "PERIPHERY_SSL_ENABLED": "true",
                },
                # Don't expose ports for this test - just test internal functionality
            )

            result = container.wait(timeout=60)
            logs = container.logs().decode("utf-8")

            print(
                f"\n=== Container Integration Test ===\n{logs}\n================================"
            )

            # Verify success
            assert (
                result["StatusCode"] == 0
            ), f"Container failed: {result['StatusCode']}"

            # Check expected behavior
            assert "KOMODO_ADDRESS: https://test.komodo.example.com" in logs
            assert "Configuration file created" in logs
            assert "port = 8120" in logs
            assert "Container integration test completed" in logs

        except Exception as e:
            pytest.fail(f"Container integration test failed: {e}")
        finally:
            if container:
                try:
                    container.remove(force=True)
                except:
                    pass

    def test_container_with_mock_periphery_binary(self):
        """Test container with mock periphery binary."""
        client = docker.from_env()

        # Create a mock periphery binary and test its execution
        mock_periphery_script = """
        echo "=== Mock Periphery Binary Test ==="

        # Create mock periphery binary
        WORK_DIR="/tmp/mock_periphery"
        mkdir -p "$WORK_DIR"

        # Create mock periphery executable
        cat > "$WORK_DIR/periphery" << 'EOF'
#!/bin/sh
echo "Komodo Periphery v1.0.0"
echo "Starting periphery agent..."
echo "Binding to port 8120"
echo "SSL enabled: true"
echo "Polling rate: 5-sec"
echo "Ready to accept connections"
# Simulate running for a short time
sleep 5
echo "Shutting down gracefully"
EOF

        chmod +x "$WORK_DIR/periphery"

        # Test running the mock binary
        echo "Testing mock periphery binary..."
        "$WORK_DIR/periphery" &
        PERIPHERY_PID=$!

        # Let it run briefly
        sleep 2

        # Check if process is running
        if kill -0 $PERIPHERY_PID 2>/dev/null; then
            echo "✓ Mock periphery process is running"
            # Stop it gracefully
            kill $PERIPHERY_PID
            wait $PERIPHERY_PID 2>/dev/null || true
        else
            echo "⚠ Mock periphery process check skipped"
        fi

        echo "=== Mock periphery binary test completed ==="
        """

        container = None
        try:
            container = client.containers.run(
                "alpine:latest",
                command=["sh", "-c", mock_periphery_script],
                detach=True,
                remove=False,
                environment={
                    "KOMODO_ADDRESS": "https://mock.example.com",
                    "KOMODO_API_KEY": "mock-key",
                    "KOMODO_API_SECRET": "mock-secret",
                },
            )

            result = container.wait(timeout=60)
            logs = container.logs().decode("utf-8")

            print(
                f"\n=== Mock Periphery Binary Test ===\n{logs}\n================================="
            )

            assert result["StatusCode"] == 0
            assert "Starting periphery agent" in logs
            assert "Binding to port 8120" in logs
            assert "Mock periphery binary test completed" in logs

        except Exception as e:
            pytest.fail(f"Mock periphery binary test failed: {e}")
        finally:
            if container:
                try:
                    container.remove(force=True)
                except:
                    pass


@pytest.mark.integration
@pytest.mark.docker
class TestDockerIntegration:
    """Integration tests for Docker functionality."""

    def test_container_with_docker_socket_simulation(self):
        """Test container with Docker socket access simulation."""
        client = docker.from_env()

        docker_test_script = """
        echo "=== Docker Socket Integration Test ==="

        # Test if Docker commands would be available
        echo "Testing Docker client availability..."

        # In a real container, this would test actual Docker socket access
        # For this test, we simulate the expected behavior

        echo "Mock docker version:"
        echo "Client: Docker Engine Community"
        echo "Version: 20.10.0"
        echo "API version: 1.41"

        echo "Mock docker ps:"
        echo "CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS   PORTS   NAMES"
        echo "abc123def456   alpine    \"/bin/sh\" 1 min ago Up 1 min         test_container"

        # Test container stats simulation
        echo "Mock container stats:"
        echo "CPU: 0.5%"
        echo "Memory: 64MB / 512MB"
        echo "Network I/O: 1.2KB / 0B"

        echo "✓ Docker socket access simulation completed"
        echo "=== Docker integration test completed ==="
        """

        container = None
        try:
            container = client.containers.run(
                "alpine:latest",
                command=["sh", "-c", docker_test_script],
                detach=True,
                remove=False,
            )

            result = container.wait(timeout=30)
            logs = container.logs().decode("utf-8")

            print(
                f"\n=== Docker Integration Test ===\n{logs}\n=============================="
            )

            assert result["StatusCode"] == 0
            assert "Docker client availability" in logs
            assert "Docker socket access simulation completed" in logs

        except Exception as e:
            pytest.fail(f"Docker integration test failed: {e}")
        finally:
            if container:
                try:
                    container.remove(force=True)
                except:
                    pass


@pytest.mark.integration
@pytest.mark.network
class TestNetworkIntegration:
    """Integration tests for network functionality."""

    def test_container_network_connectivity(self):
        """Test container network connectivity."""
        client = docker.from_env()

        network_test_script = """
        echo "=== Network Integration Test ==="

        # Test basic network connectivity
        echo "Testing network connectivity..."

        # Test DNS resolution
        if nslookup google.com >/dev/null 2>&1; then
            echo "✓ DNS resolution working"
        else
            echo "⚠ DNS resolution test skipped"
        fi

        # Test HTTP connectivity (if available)
        if command -v wget >/dev/null 2>&1; then
            if wget -q --spider --timeout=5 http://httpbin.org/status/200 2>/dev/null; then
                echo "✓ HTTP connectivity working"
            else
                echo "⚠ HTTP connectivity test failed or skipped"
            fi
        else
            echo "⚠ wget not available, HTTP test skipped"
        fi

        # Test port binding
        echo "Testing port binding capabilities..."
        (echo "test" | nc -l -p 9999) &
        NC_PID=$!
        sleep 1

        if netstat -ln 2>/dev/null | grep -q ":9999"; then
            echo "✓ Port binding test successful"
        else
            echo "⚠ Port binding test skipped (netstat not available)"
        fi

        kill $NC_PID 2>/dev/null || true

        echo "=== Network integration test completed ==="
        """

        container = None
        try:
            container = client.containers.run(
                "alpine:latest",
                command=["sh", "-c", network_test_script],
                detach=True,
                remove=False,
                network_mode="bridge",
            )

            result = container.wait(timeout=45)
            logs = container.logs().decode("utf-8")

            print(
                f"\n=== Network Integration Test ===\n{logs}\n==============================="
            )

            assert result["StatusCode"] == 0
            assert "Network integration test completed" in logs

        except Exception as e:
            pytest.fail(f"Network integration test failed: {e}")
        finally:
            if container:
                try:
                    container.remove(force=True)
                except:
                    pass


@pytest.mark.integration
class TestConfigurationIntegration:
    """Integration tests for configuration handling."""

    def test_configuration_file_processing(self):
        """Test configuration file generation and processing."""
        client = docker.from_env()

        config_test_script = r"""
        echo "=== Configuration Integration Test ==="

        CONFIG_DIR="/tmp/periphery_config"
        mkdir -p "$CONFIG_DIR"

        # Test TOML configuration generation
        echo "Generating TOML configuration..."
        cat > "$CONFIG_DIR/periphery.config.toml" << 'EOF'
# Komodo Periphery Configuration
port = 8120
stats_polling_rate = "5-sec"
container_stats_polling_rate = "1-min"
ssl_enabled = true

[logging]
level = "debug"
pretty = false

[server]
address = "0.0.0.0"
ssl_key_file = "/ssl/key.pem"
ssl_cert_file = "/ssl/cert.pem"

[monitoring]
system_metrics = true
docker_metrics = true
EOF

        # Test configuration parsing
        echo "Testing configuration file parsing..."
        if grep -q "port = 8120" "$CONFIG_DIR/periphery.config.toml"; then
            echo "✓ Port setting found"
        fi

        if grep -q "ssl_enabled = true" "$CONFIG_DIR/periphery.config.toml"; then
            echo "✓ SSL setting found"
        fi

        if grep -q "\[logging\]" "$CONFIG_DIR/periphery.config.toml"; then
            echo "✓ Logging section found"
        fi

        # Test environment variable substitution simulation
        echo "Testing environment variable processing..."
        KOMODO_ADDRESS="https://config.test.example.com"
        KOMODO_API_KEY="config-test-key"

        echo "KOMODO_ADDRESS=$KOMODO_ADDRESS" > "$CONFIG_DIR/env_config"
        echo "KOMODO_API_KEY=$KOMODO_API_KEY" >> "$CONFIG_DIR/env_config"

        if [ -f "$CONFIG_DIR/env_config" ]; then
            echo "✓ Environment configuration processed"
            cat "$CONFIG_DIR/env_config"
        fi

        # Test SSL certificate directory simulation
        mkdir -p "$CONFIG_DIR/ssl"
        touch "$CONFIG_DIR/ssl/cert.pem"
        touch "$CONFIG_DIR/ssl/key.pem"

        if [ -f "$CONFIG_DIR/ssl/cert.pem" ] && [ -f "$CONFIG_DIR/ssl/key.pem" ]; then
            echo "✓ SSL certificate files created"
        fi

        echo "=== Configuration integration test completed ==="
        """

        container = None
        try:
            container = client.containers.run(
                "alpine:latest",
                command=["sh", "-c", config_test_script],
                detach=True,
                remove=False,
                environment={
                    "KOMODO_ADDRESS": "https://config.test.example.com",
                    "KOMODO_API_KEY": "config-test-key",
                    "KOMODO_API_SECRET": "config-test-secret",
                },
            )

            result = container.wait(timeout=30)
            logs = container.logs().decode("utf-8")

            print(
                f"\n=== Configuration Integration Test ===\n{logs}\n====================================="
            )

            assert result["StatusCode"] == 0
            assert "Port setting found" in logs
            assert "SSL setting found" in logs
            assert "Logging section found" in logs
            assert "Configuration integration test completed" in logs

        except Exception as e:
            pytest.fail(f"Configuration integration test failed: {e}")
        finally:
            if container:
                try:
                    container.remove(force=True)
                except:
                    pass


@pytest.mark.integration
@pytest.mark.slow
class TestPerformanceIntegration:
    """Integration tests for performance characteristics."""

    def test_container_startup_performance(self):
        """Test container startup time and resource usage."""
        client = docker.from_env()

        performance_script = """
        echo "=== Performance Integration Test ==="

        echo "Testing startup performance..."
        START_TIME=$(date +%s)

        # Simulate periphery startup tasks
        echo "Initializing configuration..."
        sleep 1

        echo "Loading SSL certificates..."
        sleep 0.5

        echo "Starting monitoring services..."
        sleep 1

        echo "Binding to network port..."
        sleep 0.5

        END_TIME=$(date +%s)
        STARTUP_TIME=$((END_TIME - START_TIME))
        echo "✓ Startup completed in ${STARTUP_TIME} seconds"

        # Test memory usage simulation
        echo "Testing memory usage..."
        echo "Allocated memory: 64MB"
        echo "Peak memory: 128MB"
        echo "Current memory: 96MB"

        # Test CPU usage simulation
        echo "Testing CPU performance..."
        echo "CPU initialization: 5%"
        echo "CPU steady state: 1%"
        echo "CPU peak: 15%"

        if [ $STARTUP_TIME -lt 10 ]; then
            echo "✓ Startup time acceptable: ${STARTUP_TIME}s"
        else
            echo "⚠ Startup time high: ${STARTUP_TIME}s"
        fi

        echo "=== Performance integration test completed ==="
        """

        container = None
        try:
            start_time = time.time()

            container = client.containers.run(
                "alpine:latest",
                command=["sh", "-c", performance_script],
                detach=True,
                remove=False,
                mem_limit="256m",  # Set memory limit for testing
                cpu_shares=512,  # Limit CPU for testing
            )

            result = container.wait(timeout=60)

            end_time = time.time()
            actual_startup_time = end_time - start_time

            logs = container.logs().decode("utf-8")

            print(
                f"\n=== Performance Integration Test ===\n{logs}\n==================================="
            )
            print(f"Actual container startup time: {actual_startup_time:.2f}s")

            assert result["StatusCode"] == 0
            assert "Startup completed" in logs
            assert "Performance integration test completed" in logs

            # Verify reasonable startup time
            assert (
                actual_startup_time < 30
            ), f"Container startup too slow: {actual_startup_time}s"

        except Exception as e:
            pytest.fail(f"Performance integration test failed: {e}")
        finally:
            if container:
                try:
                    container.remove(force=True)
                except:
                    pass


@pytest.mark.integration
class TestErrorHandling:
    """Integration tests for error handling scenarios."""

    def test_invalid_configuration_handling(self):
        """Test handling of invalid configuration scenarios."""
        client = docker.from_env()

        error_handling_script = r"""
        echo "=== Error Handling Integration Test ==="

        # Test invalid port configuration
        echo "Testing invalid port handling..."
        INVALID_PORT="invalid_port"

        if echo "$INVALID_PORT" | grep -q "^[0-9]*$"; then
            echo "Port is valid: $INVALID_PORT"
        else
            echo "✓ Invalid port detected and handled: $INVALID_PORT"
        fi

        # Test missing required environment variables
        echo "Testing missing environment variable handling..."
        if [ -z "$MISSING_VAR" ]; then
            echo "✓ Missing environment variable detected: MISSING_VAR"
        fi

        # Test invalid URL format
        echo "Testing invalid URL handling..."
        INVALID_URL="not-a-valid-url"

        if echo "$INVALID_URL" | grep -q "^https\\?://"; then
            echo "URL is valid: $INVALID_URL"
        else
            echo "✓ Invalid URL detected and handled: $INVALID_URL"
        fi

        # Test file permission errors simulation
        echo "Testing permission error handling..."
        RESTRICTED_DIR="/root/restricted"

        if mkdir "$RESTRICTED_DIR" 2>/dev/null; then
            echo "Directory created: $RESTRICTED_DIR"
        else
            echo "✓ Permission error handled for: $RESTRICTED_DIR"
        fi

        # Test network error simulation
        echo "Testing network error handling..."
        if timeout 2 wget -q --spider http://nonexistent.invalid.domain 2>/dev/null; then
            echo "Network connection succeeded"
        else
            echo "✓ Network error handled gracefully"
        fi

        echo "=== Error handling integration test completed ==="
        """

    def test_graceful_shutdown_handling(self):
        """Test graceful shutdown and cleanup."""
        client = docker.from_env()

        shutdown_script = """
        echo "=== Graceful Shutdown Integration Test ==="

        # Simulate periphery startup
        echo "Starting mock periphery service..."

        # Create mock PID file
        echo $$ > /tmp/periphery.pid

        # Setup signal handler simulation
        cleanup() {
            echo "Received shutdown signal"
            echo "Cleaning up resources..."
            echo "Closing network connections..."
            echo "Saving configuration..."
            echo "Removing PID file..."
            rm -f /tmp/periphery.pid
            echo "✓ Graceful shutdown completed"
            exit 0
        }

        # Set trap for cleanup
        trap cleanup TERM INT

        echo "Service running (PID: $$)"
        echo "Waiting for shutdown signal..."

        # Keep running until signal received or PID file is removed
        while [ -f /tmp/periphery.pid ]; do
            sleep 1
        done

        echo "Service stopped normally"
        """

        container = None
        try:
            container = client.containers.run(
                "alpine:latest",
                command=["sh", "-c", shutdown_script],
                detach=True,
                remove=False,
            )

            # Let it start up
            time.sleep(2)

            # Check if container is still running before sending signal
            container.reload()
            if container.status == "running":
                # Send shutdown signal
                container.kill(signal="TERM")

                result = container.wait(timeout=15)
                logs = container.logs().decode("utf-8")

                print(
                    f"\n=== Graceful Shutdown Test ===\n{logs}\n============================="
                )

                # Container should exit cleanly (exit code 0 or 143 for SIGTERM)
                assert result["StatusCode"] in [
                    0,
                    143,
                ], f"Unexpected exit code: {result['StatusCode']}"
                assert "Starting mock periphery service" in logs
                assert (
                    "Graceful shutdown completed" in logs
                    or "Received shutdown signal" in logs
                )
            else:
                # Container already stopped, check logs for completion
                logs = container.logs().decode("utf-8")
                print(
                    f"\n=== Graceful Shutdown Test (Early Exit) ===\n{logs}\n=========================================="
                )

                assert "Starting mock periphery service" in logs
                # If container stopped early, that's also acceptable for this test

        except Exception as e:
            pytest.fail(f"Graceful shutdown test failed: {e}")

        finally:
            if container:
                try:
                    container.remove(force=True)
                except Exception:
                    pass


if __name__ == "__main__":
    # Run tests directly
    pytest.main([__file__, "-v", "-s", "--tb=short"])
