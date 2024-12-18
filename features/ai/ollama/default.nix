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
}
