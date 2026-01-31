# LiteLLM - Unified interface for multiple LLM providers.
# Supports OpenAI, Anthropic, Azure, Cohere, Ollama, and many others.
# Integrated with Ollama for local LLM inference.
{
  pkgs,
  config,
  lib,
  ...
}: let
  # Configuration file with Ollama models
  # These models match the ones loaded in the ollama service
  litellmConfig = pkgs.writeText "litellm-config.yaml" ''
    model_list:
      - model_name: ollama/qwen3:14b
        litellm_params:
          model: ollama/qwen3:14b
          api_base: http://localhost:11434
      - model_name: ollama/glm-4.7-flash
        litellm_params:
          model: ollama/glm-4.7-flash
          api_base: http://localhost:11434
  '';

  # Generate secure keys
  # TODO: Replace these with proper secrets management (age/agenix) or generate securely
  # You can generate keys with: openssl rand -hex 32
  masterKey = "b632c9a6e9c58ace8b896cf88842f7975c1c487a5a1d5fe07daea420ca04d683";
  # Generate with: openssl rand -hex 32 (DO NOT CHANGE ONCE SET)
  saltKey = "8bea549e337df0b95fb0504d03725d1688a79b820dc85287d6c2e2e211068770";
in {
  config = {
    # Configure LiteLLM's database and user within the main PostgreSQL service.
    # Assumes services.postgresql.enable = true; is set elsewhere in the system (e.g. hosts/mimir/flake.nix).
    services.postgresql = {
      ensureUsers = [
        {
          name = "litellm";
          password = "REPLACE_WITH_SECURE_POSTGRES_PASSWORD"; # Secure password for litellm user
        }
      ];
      ensureDatabases = [
        {
          name = "litellm";
          owner = "litellm";
        }
      ];
    };

    systemd.services = {
      litellm = {
        description = "LiteLLM Proxy Server - Unified LLM Interface";
        wantedBy = ["multi-user.target"];
        after = ["network.target" "postgresql.service"];
        requires = ["postgresql.service"];

        serviceConfig = {
          Type = "simple";
          User = "litellm";
          Group = "litellm";
          ExecStart = "${pkgs.litellm}/bin/litellm --config ${litellmConfig}";
          Restart = "always";
          RestartSec = "5s";
          WorkingDirectory = "/var/lib/litellm";

          # Environment variables
          Environment = [
            "LITELLM_MASTER_KEY=${masterKey}"
            "LITELLM_SALT_KEY=${saltKey}"
            "DATABASE_URL=postgresql://litellm@localhost/litellm"
            "PORT=4000"
            "STORE_MODEL_IN_DB=True"
          ];

          # Security settings
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = ["/var/lib/litellm"];
          NoNewPrivileges = true;
        };
      };
    };

    # Create litellm user and group
    users = {
      users = {
        litellm = {
          isSystemUser = true;
          group = "litellm";
          home = "/var/lib/litellm";
          createHome = true;
          description = "LiteLLM service user";
        };
      };
      groups = {
        litellm = {};
      };
    };

    # Create data directory
    systemd.tmpfiles.rules = [
      "d /var/lib/litellm 0755 litellm litellm - -"
    ];
  };
}
