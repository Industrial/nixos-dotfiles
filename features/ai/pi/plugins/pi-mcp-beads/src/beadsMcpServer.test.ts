import { afterEach, beforeEach, describe, expect, it } from "bun:test";
import {
    BD_TOOL_SPECS,
    BD_TOOL_TEST_CASES,
    EXPECTED_TOOL_NAMES,
    getToolSpec,
} from "./bdToolSpecs";
import {
    beadsTools,
    executeBdCommand,
    getBeadsTool,
    setExecuteBdCommandForTests,
} from "./beadsMcpServer";
import { buildBdCommandFromSpec } from "./buildBdCommand";

interface RecordedCall {
    command: string;
    output: string;
}

let recordedCalls: RecordedCall[] = [];

function installMockExecutor() {
    recordedCalls = [];
    setExecuteBdCommandForTests(async (command: string) => {
        const output = `mock-output:${command}`;
        recordedCalls.push({ command, output });
        return output;
    });
}

describe("beadsTools registry", () => {
    it("exports one MCP tool per README bd command", () => {
        expect(beadsTools).toHaveLength(EXPECTED_TOOL_NAMES.length);
        expect(beadsTools.map((tool) => tool.name)).toEqual(EXPECTED_TOOL_NAMES);
    });

    it("matches the declarative tool specs", () => {
        expect(beadsTools.map((tool) => tool.name)).toEqual(
            BD_TOOL_SPECS.map((spec) => spec.name),
        );
    });

    it("uses unique tool names", () => {
        const names = beadsTools.map((tool) => tool.name);
        expect(new Set(names).size).toBe(names.length);
    });
});

describe("buildBdCommandFromSpec", () => {
    for (const testCase of BD_TOOL_TEST_CASES) {
        if (testCase.throws || !testCase.command) {
            continue;
        }

        it(`maps ${testCase.tool} args to '${testCase.command}'`, () => {
            const spec = getToolSpec(testCase.tool);
            const command = testCase.command!;
            expect(buildBdCommandFromSpec(spec, testCase.args ?? {})).toBe(
                command,
            );
        });
    }
});

describe("tool handlers", () => {
    beforeEach(() => installMockExecutor());
    afterEach(() => setExecuteBdCommandForTests(undefined));

    for (const testCase of BD_TOOL_TEST_CASES) {
        if (testCase.throws) {
            it(`${testCase.tool} throws when validation fails`, async () => {
                const tool = getBeadsTool(testCase.tool);
                await expect(tool.handler(testCase.args ?? {})).rejects.toThrow(
                    testCase.throws,
                );
                expect(recordedCalls).toHaveLength(0);
            });
            continue;
        }

        it(`${testCase.tool} invokes bd and returns trimmed output`, async () => {
            const spec = getToolSpec(testCase.tool);
            const tool = getBeadsTool(testCase.tool);
            const command = testCase.command!;
            const result = await tool.handler(testCase.args ?? {});

            expect(recordedCalls).toHaveLength(1);
            expect(recordedCalls[0]?.command).toBe(command);
            expect(result).toEqual({
                [spec.outputKey]: `mock-output:${command}`,
            });
        });
    }
});

describe("executeBdCommand (default implementation)", () => {
    beforeEach(() => setExecuteBdCommandForTests(undefined));
    afterEach(() => setExecuteBdCommandForTests(undefined));

    it("runs bd --version when bd is on PATH", async () => {
        if (!Bun.which("bd")) {
            return;
        }

        await expect(executeBdCommand("--version")).resolves.toMatch(/bd version/i);
    });
});
