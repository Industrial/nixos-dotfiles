import { describe, expect, it } from "bun:test";
import { createBeadsMcpServer } from "./mcpServer";
import { EXPECTED_TOOL_NAMES } from "./bdToolSpecs";

describe("createBeadsMcpServer", () => {
    it("registers all beads tools for MCP list_tools", () => {
        const server = createBeadsMcpServer();
        expect(server).toBeDefined();
        expect(EXPECTED_TOOL_NAMES.length).toBe(85);
    });
});
