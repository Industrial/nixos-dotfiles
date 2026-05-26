"""
schemas.py — Tool schemas for id-hermes-superpowers

Each schema is a plain dict matching the JSON-schema format Hermes passes to
the LLM.  Add one dict per tool, then reference it in __init__.register().

Naming convention:  SP_<TOOLNAME_UPPER>

Example shape:

    SP_BRAINSTORM = {
        "name": "sp_brainstorm",
        "description": (
            "Activates the Superpowers brainstorming workflow. "
            "Explores user intent and requirements before any implementation."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "topic": {
                    "type": "string",
                    "description": "The feature, idea, or problem to brainstorm.",
                },
                "issue_id": {
                    "type": "string",
                    "description": "Optional Beads issue ID to associate with the design.",
                },
            },
            "required": ["topic"],
        },
    }
"""

# ---------------------------------------------------------------------------
# Tool schemas — add below as workflows are implemented
# ---------------------------------------------------------------------------
