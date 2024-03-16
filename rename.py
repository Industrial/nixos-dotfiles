import os
import re


def rename_files(directory):
    for filename in os.listdir(directory):
        if filename.startswith("test_") and filename.endswith(".nix"):
            new_filename = re.sub(r"^test_(.*).nix$", r"\1_test.nix", filename)
            os.rename(
                os.path.join(directory, filename), os.path.join(directory, new_filename)
            )
        elif os.path.isdir(os.path.join(directory, filename)):
            rename_files(os.path.join(directory, filename))


rename_files(".")
