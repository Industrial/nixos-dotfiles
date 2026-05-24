import { BD_TOOL_SPECS } from "./bdToolSpecs";
import { createToolFromSpec } from "./buildBdCommand";
import type { BeadsTool } from "./bdTypes";

let executeBdCommandOverride: ((command: string) => Promise<string>) | undefined;

export function setExecuteBdCommandForTests(
    fn: ((command: string) => Promise<string>) | undefined,
): void {
    executeBdCommandOverride = fn;
}

async function defaultExecuteBdCommand(command: string): Promise<string> {
    const cwd = process.env.BEADS_MCP_CWD ?? process.cwd();
    const shellCommand = `bd ${command}`;

    const proc = Bun.spawn(["sh", "-c", shellCommand], {
        cwd,
        stdout: "pipe",
        stderr: "pipe",
        env: process.env,
    });

    const [stdout, stderr, exitCode] = await Promise.all([
        new Response(proc.stdout).text(),
        new Response(proc.stderr).text(),
        proc.exited,
    ]);

    if (exitCode !== 0) {
        const detail = stderr.trim() || stdout.trim() || `exit code ${exitCode}`;
        throw new Error(
            `Failed to execute bd command "${command}". Error: ${detail}`,
        );
    }

    return stdout;
}

export async function executeBdCommand(command: string): Promise<string> {
    if (executeBdCommandOverride) {
        return executeBdCommandOverride(command);
    }
    return defaultExecuteBdCommand(command);
}

export const beadsTools: BeadsTool[] = BD_TOOL_SPECS.map((spec) =>
    createToolFromSpec(spec, executeBdCommand),
);

export function getBeadsTool(name: string): BeadsTool {
    const tool = beadsTools.find((entry) => entry.name === name);
    if (!tool) {
        throw new Error(`Unknown beads tool: ${name}`);
    }
    return tool;
}

export const getBdVersionTool = getBeadsTool("bd_version");
export const listBeadsIssuesTool = getBeadsTool("bd_list");
export const showBeadsIssueTool = getBeadsTool("bd_show");
export const createBeadsIssueTool = getBeadsTool("bd_create");
export const syncGitTool = getBeadsTool("bd_sync");
