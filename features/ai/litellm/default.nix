{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      litellm
    ];
  };
}
# # LiteLLM - Unified interface for multiple LLM providers.
# # Supports OpenAI, Anthropic, Azure, Cohere, Ollama, and many others.
# # Integrated with Ollama for local LLM inference.
# # Uses the native NixOS services.litellm module.
# {
#   pkgs,
#   config,
#   lib,
#   ...
# }: let
#   # Generate secure master key for API authentication (optional but recommended)
#   # TODO: Replace with proper secrets management (age/agenix) or generate securely
#   # You can generate keys with: openssl rand -hex 32
#   masterKey = "b632c9a6e9c58ace8b896cf88842f7975c1c487a5a1d5fe07daea420ca04d683";
#   # Generate with: openssl rand -hex 32 (DO NOT CHANGE ONCE SET)
#   saltKey = "8bea549e337df0b95fb0504d03725d1688a79b820dc85287d6c2e2e211068770";
# in {
#   enviroment = {
#     systemPackages = with pkgs; [
#       litellm
#     ];
#   };
#   # config = {
#   #   # PostgreSQL configuration - use postgres user with password authentication
#   #   services.postgresql = {
#   #     enable = true;
#   #     enableTCPIP = true;
#   #     port = 5432;
#   #     # Allow md5 authentication for localhost TCP connections
#   #     authentication = ''
#   #       local all all peer
#   #       host all all 127.0.0.1/32 md5
#   #       host all all ::1/128 md5
#   #     '';
#   #     # Ensure databases exist (idempotent)
#   #     ensureDatabases = ["litellm"];
#   #     # Set postgres user password via initialScript
#   #     initialScript = pkgs.writeText "litellm-postgres-init.sql" ''
#   #       ALTER USER postgres WITH PASSWORD 'postgres';
#   #     '';
#   #   };
#   #   # Systemd service to generate Prisma binaries before LiteLLM starts
#   #   # This is required when DATABASE_URL is set
#   #   systemd.services.litellm-prisma-setup = {
#   #     description = "Generate Prisma binaries for LiteLLM";
#   #     before = ["litellm.service"];
#   #     requiredBy = ["litellm.service"];
#   #     serviceConfig = {
#   #       Type = "oneshot";
#   #       RemainAfterExit = true;
#   #       # Ensure we have access to shell utilities
#   #       # Note: bash must be in PATH for npx to work (it spawns sh)
#   #       Environment = [
#   #         "PATH=${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gnused pkgs.gnugrep pkgs.nodejs pkgs.prisma-engines]}${
#   #           if lib.hasAttr "prisma" pkgs
#   #           then ":${lib.makeBinPath [pkgs.prisma]}"
#   #           else ""
#   #         }"
#   #         "SHELL=${pkgs.bash}/bin/bash"
#   #       ];
#   #       ExecStart = let
#   #         litellmPackage = config.services.litellm.package or pkgs.litellm;
#   #       in
#   #         pkgs.writeShellScript "litellm-prisma-generate" ''
#   #           #!${pkgs.bash}/bin/bash
#   #           set -euo pipefail
#   #           # Find the litellm package path by following the symlink
#   #           LITELLM_BIN="${lib.getExe litellmPackage}"
#   #           LITELLM_PACKAGE_PATH=$(${pkgs.coreutils}/bin/readlink -f "$LITELLM_BIN" | ${pkgs.gnused}/bin/sed 's|/bin/litellm||' || ${pkgs.coreutils}/bin/dirname "$LITELLM_BIN" | ${pkgs.coreutils}/bin/xargs ${pkgs.coreutils}/bin/dirname)
#   #           # Find the Python site-packages directory
#   #           # The package structure is: /nix/store/...-python3.X-litellm-X.X.X/lib/python3.X/site-packages/litellm
#   #           LITELLM_LIB=$(${pkgs.findutils}/bin/find "$LITELLM_PACKAGE_PATH" -type d -path "*/site-packages/litellm" 2>/dev/null | ${pkgs.coreutils}/bin/head -1)
#   #           if [ -z "$LITELLM_LIB" ]; then
#   #             echo "Error: Could not find litellm package directory in $LITELLM_PACKAGE_PATH"
#   #             exit 1
#   #           fi
#   #           PROXY_DIR="$LITELLM_LIB/proxy"
#   #           DB_DIR="$PROXY_DIR/db"
#   #           if [ ! -d "$DB_DIR" ]; then
#   #             echo "Error: Could not find litellm/proxy/db directory at $DB_DIR"
#   #             exit 1
#   #           fi
#   #           # Find schema.prisma file (it's in the proxy directory, not db)
#   #           SCHEMA_FILE="$PROXY_DIR/schema.prisma"
#   #           if [ ! -f "$SCHEMA_FILE" ]; then
#   #             echo "Error: Could not find schema.prisma at $SCHEMA_FILE"
#   #             exit 1
#   #           fi
#   #           # Don't set Prisma engine environment variables - let Prisma 6.x download its own matching engines
#   #           # The engines from nixpkgs are version 7.x which don't match Prisma 6.x CLI
#   #           # The /nix/store is read-only, so we need to copy files to a writable location
#   #           # Use the LiteLLM state directory which is writable
#   #           WORK_DIR="/var/lib/litellm/prisma-generate"
#   #           ${pkgs.coreutils}/bin/mkdir -p "$WORK_DIR"
#   #           # Copy schema.prisma to work directory
#   #           ${pkgs.coreutils}/bin/cp "$SCHEMA_FILE" "$WORK_DIR/schema.prisma"
#   #           # Change to work directory
#   #           cd "$WORK_DIR"
#   #           # Run prisma generate
#   #           echo "Generating Prisma binaries in $(${pkgs.coreutils}/bin/pwd) with schema schema.prisma"
#   #           # Ensure HOME is set and create it if needed
#   #           export HOME=/tmp/prisma-home-$$-$RANDOM
#   #           ${pkgs.coreutils}/bin/mkdir -p "$HOME"
#   #           # Create a symlink for sh -> bash so npx can find it
#   #           ${pkgs.coreutils}/bin/ln -sf ${pkgs.bash}/bin/bash "$HOME/sh" || true
#   #           export PATH="$HOME:$PATH"
#   #           # Use Prisma 6.x which is compatible with LiteLLM's schema format
#   #           # Prisma 7.x removed support for url in datasource, but LiteLLM uses the old format
#   #           echo "Using Prisma 6.x (compatible with LiteLLM schema)"
#   #           ${pkgs.nodejs}/bin/npx --yes prisma@6.1.0 generate --schema="schema.prisma" || {
#   #             echo "Warning: prisma generate failed, but continuing..."
#   #             exit 0
#   #           }
#   #           # Copy generated client to state directory (nix store is read-only)
#   #           # The prisma-client-py generator creates a structure that can be imported
#   #           if [ -d "generated" ]; then
#   #             STATE_GENERATED="/var/lib/litellm/generated"
#   #             echo "Copying generated Prisma client to $STATE_GENERATED"
#   #             ${pkgs.coreutils}/bin/rm -rf "$STATE_GENERATED"
#   #             ${pkgs.coreutils}/bin/cp -r generated "$STATE_GENERATED"
#   #             echo "Generated Prisma client available at $STATE_GENERATED"
#   #           else
#   #             echo "Warning: Generated directory not found after prisma generate"
#   #           fi
#   #           # Clean up work directory (keep generated client in state dir)
#   #           ${pkgs.coreutils}/bin/rm -rf "$HOME" "$WORK_DIR" || true
#   #           echo "Prisma binaries generation completed"
#   #         '';
#   #     };
#   #   };
#   #   # Native NixOS LiteLLM service
#   #   services.litellm = {
#   #     enable = true;
#   #     port = 4000;
#   #     host = "127.0.0.1";
#   #     # Model configuration - matches Ollama models
#   #     settings = {
#   #       model_list = [
#   #         {
#   #           model_name = "ollama/glm-4.7-flash";
#   #           litellm_params = {
#   #             model = "ollama/glm-4.7-flash";
#   #             api_base = "http://localhost:11434";
#   #           };
#   #         }
#   #       ];
#   #     };
#   #     # Environment variables for database and configuration
#   #     environment = {
#   #       LITELLM_MASTER_KEY = masterKey;
#   #       LITELLM_SALT_KEY = saltKey;
#   #       DATABASE_URL = "postgresql://postgres:postgres@localhost/litellm";
#   #       STORE_MODEL_IN_DB = "True";
#   #       # Add generated Prisma client to Python path
#   #       PYTHONPATH = "/var/lib/litellm/generated";
#   #     };
#   #   };
#   # };
# }

