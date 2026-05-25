import type { ParamSpec } from "./bdTypes";

export const issueIds = (
    description = "Issue IDs to operate on.",
    required = true,
): ParamSpec => ({
    name: "issueIds",
    type: "string[]",
    description,
    required,
    position: "leading",
    joinWith: " ",
    quote: false,
});

export const listFilterParams: ParamSpec[] = [
    {
        name: "all",
        type: "boolean",
        description: "Show all issues including closed.",
        flag: "all",
    },
    {
        name: "assignee",
        type: "string",
        description: "Filter by assignee.",
        shortFlag: "a",
    },
    {
        name: "parent",
        type: "string",
        description: "Filter by parent issue ID (shows children).",
        flag: "parent",
    },
    {
        name: "status",
        type: "string",
        description: "Filter by status (open, in_progress, blocked, deferred, closed).",
        shortFlag: "s",
    },
    {
        name: "type",
        type: "string",
        description: "Filter by issue type.",
        shortFlag: "t",
    },
    {
        name: "label",
        type: "string[]",
        description: "Filter by labels (AND: must have ALL).",
        shortFlag: "l",
        joinWith: " ",
    },
    {
        name: "labelAny",
        type: "string[]",
        description: "Filter by labels (OR: must have AT LEAST ONE).",
        flag: "label-any",
        joinWith: " ",
    },
    {
        name: "priority",
        type: "string",
        description: "Filter by priority (0-4 or P0-P4).",
        shortFlag: "p",
    },
    {
        name: "priorityMin",
        type: "string",
        description: "Filter by minimum priority (inclusive).",
        flag: "priority-min",
    },
    {
        name: "priorityMax",
        type: "string",
        description: "Filter by maximum priority (inclusive).",
        flag: "priority-max",
    },
    {
        name: "title",
        type: "string",
        description: "Filter by title substring.",
        flag: "title",
    },
    {
        name: "titleContains",
        type: "string",
        description: "Filter by title substring (case-insensitive).",
        flag: "title-contains",
    },
    {
        name: "tree",
        type: "boolean",
        description: "Hierarchical tree format (default in bd 1.0.x).",
        flag: "tree",
    },
    {
        name: "flat",
        type: "boolean",
        description: "Disable tree format; use flat list output.",
        flag: "flat",
    },
    {
        name: "ready",
        type: "boolean",
        description: "Show only ready issues (no blockers).",
        flag: "ready",
    },
    {
        name: "noParent",
        type: "boolean",
        description: "Exclude child issues (top-level only).",
        flag: "no-parent",
    },
];

export const sortParams: ParamSpec[] = [
    {
        name: "sort",
        type: "string",
        description: "Sort by field: priority, created, updated, closed, status, id, title, type, assignee.",
        flag: "sort",
    },
    {
        name: "reverse",
        type: "boolean",
        description: "Reverse the sort order.",
        shortFlag: "r",
    },
    {
        name: "limit",
        type: "number",
        description: "Maximum number of issues to return (0 = unlimited).",
        shortFlag: "n",
    },
];

export const passthrough = (
    name: string,
    subcommand: string,
    description: string,
    commandParam = "command",
): import("./bdTypes").BdToolSpec => ({
    name,
    description,
    subcommand,
    outputKey: "result",
    params: [
        {
            name: commandParam,
            type: "string",
            description: `Subcommand arguments for ${subcommand}.`,
            required: true,
            position: "trailing",
            quote: false,
        },
    ],
});
