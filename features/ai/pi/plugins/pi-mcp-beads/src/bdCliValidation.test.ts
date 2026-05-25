import { describe, expect, it } from "bun:test";
import { buildBdCommandFromSpec } from "./buildBdCommand";
import { getToolSpec } from "./bdToolSpecs";

describe("bd CLI command mapping (targets bd 1.0.x)", () => {
    it("lists children via --parent (not --query)", () => {
        const command = buildBdCommandFromSpec(getToolSpec("bd_list"), {
            parent: "dotfiles-5a3",
            json: true,
        });
        expect(command).toBe("list --parent dotfiles-5a3 --json");
        expect(command).not.toContain("--query");
    });

    it("links parent-child via bd link with type (not relation)", () => {
        const linkCmd = buildBdCommandFromSpec(getToolSpec("bd_link"), {
            issueId1: "dotfiles-70e",
            issueId2: "dotfiles-5a3",
            type: "parent-child",
        });
        expect(linkCmd).toBe("link dotfiles-70e dotfiles-5a3 -t parent-child");
        expect(linkCmd).not.toContain("relation");
    });

    it("updates fields via bd update (not bd edit --field)", () => {
        const command = buildBdCommandFromSpec(getToolSpec("bd_update"), {
            issueIds: ["dotfiles-70e"],
            parent: "dotfiles-5a3",
        });
        expect(command).toBe("update dotfiles-70e --parent dotfiles-5a3");
        expect(command).not.toContain("--field");
    });

    it("creates from graph file without --batch", () => {
        const command = buildBdCommandFromSpec(getToolSpec("bd_create"), {
            graph: "issues.graph.json",
        });
        expect(command).toBe('create --graph "issues.graph.json"');
        expect(command).not.toContain("--batch");
    });

    it("show supports children flag (bd 1.0+)", () => {
        const command = buildBdCommandFromSpec(getToolSpec("bd_show"), {
            issueIds: ["dotfiles-5a3"],
            children: true,
        });
        expect(command).toBe("show dotfiles-5a3 --children");
    });
});
