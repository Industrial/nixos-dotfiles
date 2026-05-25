import type { BdToolSpec, ParamSpec } from "./bdTypes";

const GLOBAL_PARAMS: ParamSpec[] = [
    {
        name: "actor",
        type: "string",
        description: "Actor name for audit trail logging.",
        flag: "actor",
    },
    {
        name: "db",
        type: "string",
        description: "Database path (default: auto-discover .beads/*.db).",
        flag: "db",
    },
    {
        name: "json",
        type: "boolean",
        description: "Output results in JSON format.",
        flag: "json",
    },
    {
        name: "allowStale",
        type: "boolean",
        description: "Allow operations on potentially stale data.",
        flag: "allow-stale",
    },
    {
        name: "noDaemon",
        type: "boolean",
        description: "Force direct storage mode, bypass daemon if running.",
        flag: "no-daemon",
    },
    {
        name: "noDb",
        type: "boolean",
        description: "Use no-db mode: load from JSONL, no SQLite.",
        flag: "no-db",
    },
    {
        name: "profile",
        type: "boolean",
        description: "Generate a CPU profile.",
        flag: "profile",
    },
    {
        name: "quiet",
        type: "boolean",
        description: "Suppress non-essential output.",
        shortFlag: "q",
    },
    {
        name: "readonly",
        type: "boolean",
        description: "Run in read-only mode.",
        flag: "readonly",
    },
    {
        name: "sandbox",
        type: "boolean",
        description: "Enable sandbox mode.",
        flag: "sandbox",
    },
    {
        name: "verbose",
        type: "boolean",
        description: "Enable verbose output.",
        shortFlag: "v",
    },
];

function toKebabCase(value: string): string {
    return value.replace(/[A-Z]/g, (match) => `-${match.toLowerCase()}`);
}

function formatFlagName(param: ParamSpec): string {
    if (param.shortFlag) {
        return param.shortFlag;
    }
    return param.flag ?? toKebabCase(param.name);
}

function quoteValue(value: string, escapeQuotes: boolean): string {
    if (escapeQuotes) {
        return `"${value.replace(/"/g, '\\"')}"`;
    }
    return `"${value}"`;
}

function formatPositionalValue(value: unknown, param: ParamSpec): string {
    const stringValue = String(value);
    if (param.quote === true) {
        return quoteValue(stringValue, param.escapeQuotes ?? false);
    }
    return stringValue;
}

function formatFlagValue(param: ParamSpec, value: unknown): string {
    const flag = formatFlagName(param);
    const prefix = param.shortFlag ? `-${flag}` : `--${flag}`;

    if (param.type === "boolean") {
        return value ? prefix : "";
    }

    if (param.type === "number") {
        return `${prefix} ${value}`;
    }

    if (param.type === "string[]") {
        const items = value as string[];
        if (items.length === 0) {
            return "";
        }
        const joined = param.joinWith === ","
            ? items.join(",")
            : items.join(" ");
        if (param.joinWith === ",") {
            return `${prefix} ${joined}`;
        }
        return `${prefix} ${joined}`;
    }

    const stringValue = String(value);
    if (param.quote === true) {
        return `${prefix} ${quoteValue(stringValue, param.escapeQuotes ?? false)}`;
    }
    return `${prefix} ${stringValue}`;
}

function appendParamParts(
    parts: string[],
    param: ParamSpec,
    value: unknown,
): void {
    if (value === undefined || value === null) {
        return;
    }

    if (param.type === "boolean" && value === false) {
        return;
    }

    if (param.type === "string[]") {
        const items = value as string[];
        if (items.length === 0) {
            return;
        }
    }

    if (param.position) {
        if (param.type === "string[]") {
            const items = value as string[];
            parts.push(
                items.map((item) => formatPositionalValue(item, param)).join(" "),
            );
        } else {
            parts.push(formatPositionalValue(value, param));
        }
        return;
    }

    const formatted = formatFlagValue(param, value);
    if (formatted) {
        parts.push(formatted);
    }
}

export function buildBdCommandFromSpec(
    spec: BdToolSpec,
    args: Record<string, unknown>,
): string {
    if (spec.buildCommand) {
        return spec.buildCommand(args);
    }

    const specParamNames = new Set(spec.params.map((param) => param.name));
    const params = [
        ...spec.params,
        ...(spec.includeGlobalFlags === false
            ? []
            : GLOBAL_PARAMS.filter((param) => !specParamNames.has(param.name))),
    ];

    const parts: string[] = [spec.subcommand];

    for (const param of params) {
        const value = args[param.name];
        if (value === undefined || value === null) {
            continue;
        }
        appendParamParts(parts, param, value);
    }

    return parts.filter(Boolean).join(" ").trim();
}

export function specToJsonSchema(spec: BdToolSpec): BeadsTool["parameters"] {
    const specParamNames = new Set(spec.params.map((param) => param.name));
    const params = [
        ...spec.params,
        ...(spec.includeGlobalFlags === false
            ? []
            : GLOBAL_PARAMS.filter((param) => !specParamNames.has(param.name))),
    ];

    const properties: Record<string, unknown> = {};
    const required: string[] = [];

    for (const param of params) {
        if (param.type === "string[]") {
            properties[param.name] = {
                type: "array",
                items: { type: "string" },
                description: param.description,
            };
        } else {
            properties[param.name] = {
                type: param.type,
                description: param.description,
            };
        }
        if (param.required) {
            required.push(param.name);
        }
    }

    return { type: "object", properties, required };
}

import type { BeadsTool } from "./bdTypes";

export function createToolFromSpec(
    spec: BdToolSpec,
    execute: (command: string) => Promise<string>,
): BeadsTool {
    return {
        name: spec.name,
        description: spec.description,
        parameters: specToJsonSchema(spec),
        handler: async (args: Record<string, unknown>) => {
            spec.validate?.(args);
            const command = buildBdCommandFromSpec(spec, args);
            const output = await execute(command);
            return { [spec.outputKey]: output.trim() };
        },
    };
}

export { GLOBAL_PARAMS };
