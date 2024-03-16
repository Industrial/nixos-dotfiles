import glob
import os


def replace_content(file_path):
    with open(file_path, "r") as file:
        content = file.read()

    # Extract the 'something' part from the '<something>_test.nix' filename
    filename = os.path.basename(file_path)
    something = filename.split("_test.nix")[0]

    old_format = f"in {{\n  testPackages = {{\n    expr = builtins.elem pkgs.{something} feature.environment.systemPackages;\n    expected = true;\n  }};\n}}"
    new_format = f"in [\n  {{\n    actual = builtins.elem pkgs.{something} feature.environment.systemPackages;\n    expected = true;\n  }}\n]"

    content = content.replace(old_format, new_format)

    with open(file_path, "w") as file:
        file.write(content)


def main():
    for file_path in glob.glob("**/*_test.nix", recursive=True):
        replace_content(file_path)


if __name__ == "__main__":
    main()
