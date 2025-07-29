"""
Tests for add-on configuration validation.
"""

from pathlib import Path
from typing import Any, Dict

import yaml


class TestAddonConfig:
    """Test suite for add-on configuration validation."""

    def test_config_file_exists(self, project_root_path: Path):
        """Test that config.yaml exists."""
        config_path = project_root_path / "config.yaml"
        assert config_path.exists(), "config.yaml file must exist"

    def test_config_is_valid_yaml(self, config_data: Dict[str, Any]):
        """Test that config.yaml is valid YAML."""
        assert isinstance(
            config_data, dict), "Configuration must be a dictionary"
        assert len(config_data) > 0, "Configuration must not be empty"

    def test_required_fields_present(self, config_data: Dict[str, Any]):
        """Test that all required fields are present."""
        required_fields = [
            'name', 'version', 'slug', 'description', 'url',
            'arch', 'startup', 'boot', 'init', 'options', 'schema'
        ]

        for field in required_fields:
            assert field in config_data, f"Required field '{field}' missing from config"

    def test_addon_metadata(self, config_data: Dict[str, Any]):
        """Test add-on metadata fields."""
        assert config_data['name'] == "Komodo Periphery"
        assert config_data['slug'] == "komodo_periphery"
        assert isinstance(config_data['version'], str)
        assert len(config_data['version']) > 0
        assert isinstance(config_data['description'], str)
        assert len(config_data['description']) > 0

    def test_supported_architectures(self, config_data: Dict[str, Any]):
        """Test supported architectures are valid."""
        valid_archs = ['aarch64', 'amd64', 'armhf', 'armv7', 'i386']
        supported_archs = config_data.get('arch', [])

        assert isinstance(
            supported_archs, list), "Architectures must be a list"
        assert len(
            supported_archs) > 0, "At least one architecture must be supported"

        for arch in supported_archs:
            assert arch in valid_archs, f"Invalid architecture: {arch}"

    def test_startup_configuration(self, config_data: Dict[str, Any]):
        """Test startup configuration."""
        valid_startup_types = ['before', 'after', 'once', 'services', 'system']
        startup = config_data.get('startup')

        assert startup in valid_startup_types, f"Invalid startup type: {startup}"

    def test_boot_configuration(self, config_data: Dict[str, Any]):
        """Test boot configuration."""
        valid_boot_types = ['auto', 'manual']
        boot = config_data.get('boot')

        assert boot in valid_boot_types, f"Invalid boot type: {boot}"

    def test_ports_configuration(self, config_data: Dict[str, Any]):
        """Test ports configuration."""
        ports = config_data.get('ports', {})

        if ports:
            assert isinstance(ports, dict), "Ports must be a dictionary"

            for port_def, port_num in ports.items():
                # Test port definition format
                assert '/' in port_def, f"Port definition must include protocol: {port_def}"
                port, protocol = port_def.split('/')
                assert port.isdigit(), f"Port must be numeric: {port}"
                assert protocol in [
                    'tcp', 'udp'], f"Invalid protocol: {protocol}"

                # Test port number
                assert isinstance(
                    port_num, int), f"Port number must be integer: {port_num}"
                assert 1 <= port_num <= 65535, f"Invalid port number: {port_num}"

    def test_options_schema_consistency(self, config_data: Dict[str, Any]):
        """Test that options and schema are consistent."""
        options = config_data.get('options', {})
        schema = config_data.get('schema', {})

        # All options should have corresponding schema entries
        for option_key in options.keys():
            assert option_key in schema, f"Option '{option_key}' missing from schema"

        # All schema entries should have default values in options (except optional ones)
        for schema_key, schema_def in schema.items():
            if not str(schema_def).endswith('?'):  # Not optional
                assert schema_key in options, f"Required schema field '{schema_key}' missing from options"

    def test_required_options(self, config_data: Dict[str, Any]):
        """Test that required options are present."""
        required_options = [
            'komodo_address', 'komodo_api_key', 'komodo_api_secret',
            'log_level', 'stats_polling_rate', 'container_stats_polling_rate',
            'ssl_enabled', 'monitor_homeassistant'
        ]

        options = config_data.get('options', {})

        for option in required_options:
            assert option in options, f"Required option '{option}' missing"

    def test_schema_types(self, config_data: Dict[str, Any]):
        """Test schema type definitions."""
        schema = config_data.get('schema', {})
        valid_types = [
            'str', 'password', 'int', 'float', 'bool', 'url', 'email'
        ]

        for field, field_type in schema.items():
            if isinstance(field_type, str):
                # Handle optional types ending with ?
                base_type = field_type.rstrip('?')

                # Handle list types like [str]? or [password]?
                if base_type.startswith('[') and base_type.endswith(']'):
                    # Extract the inner type from [type]
                    inner_type = base_type[1:-1]
                    # Handle enum types like [option1|option2]
                    if '|' in inner_type:
                        continue
                    assert inner_type in valid_types, f"Invalid list schema type for '{field}': {field_type}"
                    continue

                # Handle list types like list(option1|option2|option3)
                if base_type.startswith('list(') and base_type.endswith(')'):
                    continue

                # Handle enum types with | separator
                if '|' in base_type:
                    continue

                # Validate basic types
                assert base_type in valid_types, f"Invalid schema type for '{field}': {field_type}"

    def test_environment_mapping(self, config_data: Dict[str, Any]):
        """Test environment variable mapping."""
        environment = config_data.get('environment', {})
        options = config_data.get('options', {})

        # Key environment variables should be mapped
        expected_mappings = {
            'KOMODO_ADDRESS': 'komodo_address',
            'KOMODO_API_KEY': 'komodo_api_key',
            'KOMODO_API_SECRET': 'komodo_api_secret',
            'PERIPHERY_LOG_LEVEL': 'log_level'
        }

        for env_var, option_key in expected_mappings.items():
            assert env_var in environment, f"Environment variable '{env_var}' not mapped"
            assert environment[env_var] == option_key, f"Incorrect mapping for '{env_var}'"

    def test_privileged_settings(self, config_data: Dict[str, Any]):
        """Test privileged settings are appropriate."""
        privileged = config_data.get('privileged', [])

        if privileged:
            assert isinstance(privileged, list), "Privileged must be a list"
            valid_privileges = ['SYS_ADMIN', 'NET_ADMIN',
                                'SYS_TIME', 'DAC_READ_SEARCH']

            for privilege in privileged:
                assert privilege in valid_privileges, f"Invalid privilege: {privilege}"

    def test_docker_api_access(self, config_data: Dict[str, Any]):
        """Test Docker API access configuration."""
        docker_api = config_data.get('docker_api')

        # Should be enabled for container management
        assert docker_api is True, "Docker API access should be enabled"

    def test_network_configuration(self, config_data: Dict[str, Any]):
        """Test network configuration."""
        host_network = config_data.get('host_network', False)
        host_pid = config_data.get('host_pid', False)

        # For security, these should typically be False
        assert host_network is False, "Host network should be disabled for security"
        assert host_pid is False, "Host PID should be disabled for security"

    def test_apparmor_configuration(self, config_data: Dict[str, Any]):
        """Test AppArmor configuration."""
        apparmor = config_data.get('apparmor')

        # AppArmor should be enabled for security
        assert apparmor is True, "AppArmor should be enabled for security"

    def test_services_configuration(self, config_data: Dict[str, Any]):
        """Test services configuration."""
        services = config_data.get('services', [])

        if services:
            assert isinstance(services, list), "Services must be a list"

            for service in services:
                assert isinstance(service, str), "Service must be a string"
                # Check format is "service:want" or "service:need"
                if ':' in service:
                    service_name, dependency_type = service.split(':')
                    assert dependency_type in [
                        'want', 'need'], f"Invalid dependency type: {dependency_type}"


class TestBuildConfig:
    """Test suite for build configuration validation."""

    def test_build_config_exists(self, project_root_path: Path):
        """Test that build.yaml exists."""
        build_config_path = project_root_path / "build.yaml"
        assert build_config_path.exists(), "build.yaml file must exist"

    def test_build_config_is_valid_yaml(self, build_config_data: Dict[str, Any]):
        """Test that build.yaml is valid YAML."""
        assert isinstance(build_config_data,
                          dict), "Build configuration must be a dictionary"
        assert len(build_config_data) > 0, "Build configuration must not be empty"

    def test_build_from_configuration(self, build_config_data: Dict[str, Any], config_data: Dict[str, Any]):
        """Test build_from configuration matches supported architectures."""
        build_from = build_config_data.get('build_from', {})
        supported_archs = config_data.get('arch', [])

        assert isinstance(build_from, dict), "build_from must be a dictionary"
        assert len(build_from) > 0, "build_from must not be empty"

        # All supported architectures should have base images
        for arch in supported_archs:
            assert arch in build_from, f"Missing base image for architecture: {arch}"

            base_image = build_from[arch]
            assert isinstance(
                base_image, str), f"Base image for {arch} must be a string"
            assert len(
                base_image) > 0, f"Base image for {arch} must not be empty"

            # Should use official Home Assistant base images
            assert "home-assistant" in base_image, f"Should use HA base image for {arch}"

    def test_build_args(self, build_config_data: Dict[str, Any]):
        """Test build arguments configuration."""
        args = build_config_data.get('args', {})

        if args:
            assert isinstance(args, dict), "Args must be a dictionary"

            # Check for common build arguments
            if 'KOMODO_VERSION' in args:
                assert isinstance(args['KOMODO_VERSION'],
                                  str), "KOMODO_VERSION must be a string"

    def test_labels_configuration(self, build_config_data: Dict[str, Any]):
        """Test labels configuration."""
        labels = build_config_data.get('labels', {})

        if labels:
            assert isinstance(labels, dict), "Labels must be a dictionary"

            # Check for required OCI labels
            required_labels = [
                'org.opencontainers.image.title',
                'org.opencontainers.image.description',
                'org.opencontainers.image.licenses'
            ]

            for label in required_labels:
                if label in labels:
                    assert isinstance(
                        labels[label], str), f"Label {label} must be a string"
                    assert len(
                        labels[label]) > 0, f"Label {label} must not be empty"


class TestTranslations:
    """Test suite for translations validation."""

    def test_english_translation_exists(self, project_root_path: Path):
        """Test that English translation exists."""
        translation_path = project_root_path / "translations" / "en.yaml"
        assert translation_path.exists(), "English translation file must exist"

    def test_translation_structure(self, project_root_path: Path, config_data: Dict[str, Any]):
        """Test translation file structure."""
        translation_path = project_root_path / "translations" / "en.yaml"

        assert translation_path.exists(
        ), f"Translation file must exist at: {translation_path}"

        with open(translation_path, 'r', encoding='utf-8') as f:
            translations = yaml.safe_load(f)

        assert translations is not None, "Translation file must contain valid YAML"
        assert isinstance(
            translations, dict), "Translations must be a dictionary"
        assert 'configuration' in translations, "Translations must have 'configuration' section"

        config_translations = translations['configuration']
        assert isinstance(
            config_translations, dict), "Configuration translations must be a dictionary"

        options = config_data.get('options', {})
        schema = config_data.get('schema', {})

        # All options should have translations
        for option_key in options.keys():
            assert option_key in config_translations, f"Missing translation for option: {option_key}"

            option_translation = config_translations[option_key]
            assert isinstance(
                option_translation, dict), f"Translation for {option_key} must be a dictionary"
            assert 'name' in option_translation, f"Missing 'name' in translation for: {option_key}"
            assert 'description' in option_translation, f"Missing 'description' in translation for: {option_key}"

            assert isinstance(
                option_translation['name'], str), f"Translation name for {option_key} must be string"
            assert isinstance(
                option_translation['description'], str), f"Translation description for {option_key} must be string"
            assert len(option_translation['name'].strip(
            )) > 0, f"Translation name for {option_key} must not be empty"
            assert len(option_translation['description'].strip(
            )) > 0, f"Translation description for {option_key} must not be empty"

        # All schema fields should have translations (except for optional ones marked with ?)
        for schema_key in schema.keys():
            # Skip optional fields ending with ? in their type definition
            schema_def = schema[schema_key]
            if isinstance(schema_def, str) and schema_def.endswith('?'):
                continue

            assert schema_key in config_translations, f"Missing translation for schema field: {schema_key}"

        # Check that translation keys are valid (no extra translations for non-existent options)
        all_valid_keys = set(options.keys()) | set(schema.keys())
        for translation_key in config_translations.keys():
            assert translation_key in all_valid_keys, f"Translation exists for non-existent option: {translation_key}"
