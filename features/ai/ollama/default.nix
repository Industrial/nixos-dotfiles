# AI Framework.
# Model	                    Arena Score	MT-bench	MMLU	Organization
# Gemma 2 27B Instruct	    1216	      –	        76.2	Google
# Nemotron-4 340B Instruct	1208	      –	        –	    Nvidia
# Llama 3 70b Instruct	    1207	      8.2	      79.2	Meta
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      ollama
      ollama-cuda
    ];
  };
  services = {
    ollama = {
      enable = true;
      host = "[::]";
      port = 11434;
      # acceleration = "rocm";
      loadModels = [
        "llama3.3:70b"
        "deepseek-r1:70b"
        "qwen-2.5:70b"
        "qwen-coder:30b"
      ];
    };
    nextjs-ollama-llm-ui = {
      enable = true;
      port = 5001;
    };
  };
}
