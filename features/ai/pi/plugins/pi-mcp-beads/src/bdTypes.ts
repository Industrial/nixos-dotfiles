export type ParamType = "string" | "number" | "boolean" | "string[]";

export interface ParamSpec {
    name: string;
    type: ParamType;
    description: string;
    required?: boolean;
    /** CLI flag without dashes; defaults to kebab-case of name */
    flag?: string;
    /** Short flag letter, e.g. C for -C */
    shortFlag?: string;
    /** Place positional args before flags (default trailing) */
    position?: "leading" | "trailing";
    quote?: boolean;
    escapeQuotes?: boolean;
    /** Join string[] with comma for flags like --labels */
    joinWith?: "," | " ";
}

export interface BdToolSpec {
    name: string;
    description: string;
    /** bd subcommand prefix, e.g. "dep add" */
    subcommand: string;
    params: ParamSpec[];
    outputKey: string;
    includeGlobalFlags?: boolean;
    validate?: (args: Record<string, unknown>) => void;
    buildCommand?: (args: Record<string, unknown>) => string;
}

export interface BeadsTool {
    name: string;
    description: string;
    parameters: {
        type: "object";
        properties: Record<string, unknown>;
        required: string[];
    };
    handler: (args: Record<string, unknown>) => Promise<Record<string, string>>;
}

export interface ToolTestCase {
    tool: string;
    args?: Record<string, unknown>;
    command?: string;
    throws?: string;
}
