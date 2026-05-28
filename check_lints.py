with open("analyze.txt", "rb") as f:
    text = f.read().decode("utf-16le", errors="ignore")
    lines = text.splitlines()
    for line in lines:
        if "info" in line or "error" in line or "warning" in line or "line" in line or ".dart" in line:
            print(line.strip())
