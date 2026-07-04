def greeting(name: str = "Hermes") -> str:
    clean_name = " ".join(str(name or "Hermes").split()) or "Hermes"
    return f"Hello, {clean_name}. Cursor is connected."


if __name__ == "__main__":
    print(greeting())
