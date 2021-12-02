def section(d, prefix="s"):
    """
    Helper function to generate OSCAL section structure.
    """
    id = d["id"]
    title = d["title"]
    prose = d["prose"]
    return {
        "id": f"{prefix}{id}",
        "class": "section",
        "title": title,
        "props": [{"name": "label", "value": id,}],
        "parts": [{"id": f"s{id}_smt", "name": "objective", "prose": prose}],
        "controls": [],
    }
