#!/usr/bin/env node
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

let fatalEmitted = false;
process.on("unhandledRejection", (error) => fatal(error));
process.on("uncaughtException", (error) => fatal(error));

async function main() {
  const payload = await readPayload();
  try {
    const sdk = await loadCursorSdk();
    switch ((payload.action || "run").toLowerCase()) {
      case "run":
        await runAgentTurn(sdk, payload);
        break;
      case "status":
        emit({ type: "status", success: true, sdk_version: sdkVersion() });
        break;
      case "me":
        emit({ type: "data", action: "me", result: await sdk.Cursor.me(cursorRequestOptions(payload)) });
        break;
      case "models":
        emit({ type: "data", action: "models", result: await sdk.Cursor.models.list(cursorRequestOptions(payload)) });
        break;
      case "repositories":
      case "repos":
        emit({
          type: "data",
          action: "repositories",
          result: await sdk.Cursor.repositories.list(cursorRequestOptions(payload)),
        });
        break;
      case "list_agents":
        emit({
          type: "data",
          action: "list_agents",
          result: await sdk.Agent.list(listAgentsOptions(payload)),
        });
        break;
      default:
        throw new Error(`unsupported SDK bridge action: ${payload.action}`);
    }
  } catch (error) {
    emit({ type: "error", error: errorMessage(error), name: error?.name, stack: trimmedStack(error) });
    process.exitCode = 1;
  }
}

async function runAgentTurn(sdk, payload) {
  const runtime = normalizeRuntime(payload.runtime);
  const options = buildAgentOptions(payload, runtime);
  const agentId = cleanString(payload.agent_id || payload.cursor_session_id);
  const agent = agentId ? await sdk.Agent.resume(agentId, options) : await sdk.Agent.create(options);
  emit({
    type: "agent",
    agent_id: agent.agentId,
    runtime,
    resumed: Boolean(agentId),
    model: publicModel(agent.model || options.model),
  });
  const prompt = policyWrappedPrompt(payload);
  const sendOptions = buildSendOptions(payload);
  const run = await agent.send(prompt, sendOptions);
  emit({ type: "run", agent_id: run.agentId, run_id: run.id, status: run.status, model: publicModel(run.model) });
  if (typeof run.stream === "function" && run.supports?.("stream") !== false) {
    for await (const message of run.stream()) {
      emit({ type: "sdk_event", agent_id: run.agentId, run_id: run.id, message: safeClone(message) });
    }
  }
  const result = await run.wait();
  emit({
    type: "result",
    agent_id: run.agentId,
    run_id: run.id,
    status: result.status,
    result: result.result || "",
    model: publicModel(result.model || run.model || agent.model),
    duration_ms: result.durationMs,
    git: result.git,
  });
  if (typeof agent.close === "function") {
    agent.close();
  }
}

function buildAgentOptions(payload, runtime) {
  const options = {};
  const apiKey = cleanString(payload.api_key);
  const model = modelSelection(payload.model);
  const mcpServers = normalizeMcpServers(payload.mcp_servers);
  const customAgents = normalizeCustomAgents(payload.agents);
  if (apiKey) options.apiKey = apiKey;
  if (model) options.model = model;
  if (cleanString(payload.name)) options.name = cleanString(payload.name);
  if (Object.keys(mcpServers).length) options.mcpServers = mcpServers;
  if (Object.keys(customAgents).length) options.agents = customAgents;
  if (runtime === "cloud") {
    if (!apiKey && !process.env.CURSOR_API_KEY) {
      throw new Error("Cursor SDK cloud runtime requires CURSOR_API_KEY or an api_key payload");
    }
    options.cloud = cloudOptions(payload);
  } else {
    if (!model) {
      options.model = { id: "composer-2" };
    }
    options.local = {
      cwd: cleanString(payload.project_path) || process.cwd(),
      settingSources: arrayOfStrings(payload.setting_sources, ["project", "user", "team", "plugins"]),
      sandboxOptions: { enabled: payload.sandbox_enabled !== false },
    };
  }
  return options;
}

function buildSendOptions(payload) {
  const sendOptions = {};
  const model = modelSelection(payload.model);
  const mcpServers = normalizeMcpServers(payload.mcp_servers);
  if (model) sendOptions.model = model;
  if (Object.keys(mcpServers).length) sendOptions.mcpServers = mcpServers;
  if (payload.force_local_run) sendOptions.local = { force: true };
  return sendOptions;
}

function cloudOptions(payload) {
  const cloud = {};
  const repos = normalizeCloudRepositories(payload);
  if (repos.length) cloud.repos = repos;
  if (payload.cloud_env && typeof payload.cloud_env === "object") cloud.env = payload.cloud_env;
  if (payload.work_on_current_branch !== undefined) cloud.workOnCurrentBranch = Boolean(payload.work_on_current_branch);
  if (payload.auto_create_pr !== undefined) cloud.autoCreatePR = Boolean(payload.auto_create_pr);
  if (payload.skip_reviewer_request !== undefined) cloud.skipReviewerRequest = Boolean(payload.skip_reviewer_request);
  return cloud;
}

function normalizeCloudRepositories(payload) {
  const raw = payload.cloud_repositories || payload.repositories;
  if (Array.isArray(raw)) {
    return raw
      .map((repo) => {
        if (typeof repo === "string") return { url: repo };
        if (!repo || typeof repo !== "object") return undefined;
        return {
          url: cleanString(repo.url || repo.repository),
          startingRef: cleanString(repo.startingRef || repo.starting_ref || repo.ref),
          prUrl: cleanString(repo.prUrl || repo.pr_url),
        };
      })
      .filter((repo) => repo?.url);
  }
  const url = cleanString(payload.cloud_repository || payload.repository);
  if (!url) return [];
  return [{ url, startingRef: cleanString(payload.cloud_ref || payload.ref) }];
}

function policyWrappedPrompt(payload) {
  const prompt = cleanString(payload.prompt);
  const policy = cleanString(payload.permission_policy || payload.mode);
  if (!policy) return prompt;
  const rules = {
    plan: "Inspect and reason only. Do not edit files or run mutating commands.",
    ask: "Ask for permission before edits or mutating commands.",
    edit: "Make focused repository edits needed for the task.",
    full_access: "Use broad local capabilities only for the requested task.",
    reject: "Read-only. Refuse edits, shell writes, and external side effects.",
  };
  const detail = rules[policy] || `Follow Hermes permission policy: ${policy}.`;
  return [
    "Hermes Cursor Harness policy:",
    `- mode: ${policy}`,
    `- ${detail}`,
    "",
    "User task:",
    prompt,
  ].join("\n");
}

function modelSelection(raw) {
  const value = cleanString(raw);
  if (!value || value === "cursor/default" || value === "default") return undefined;
  const id = value.startsWith("cursor/") ? value.slice("cursor/".length) : value;
  if (!id || id === "default") return undefined;
  return { id };
}

function normalizeMcpServers(raw) {
  if (!raw) return {};
  if (!Array.isArray(raw) && typeof raw === "object") return raw;
  if (!Array.isArray(raw)) return {};
  const servers = {};
  raw.forEach((item, index) => {
    if (!item || typeof item !== "object") return;
    const name = cleanString(item.name || item.id || `server_${index + 1}`);
    const copy = { ...item };
    delete copy.name;
    delete copy.id;
    servers[name] = copy;
  });
  return servers;
}

function normalizeCustomAgents(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  return raw;
}

function listAgentsOptions(payload) {
  const runtime = normalizeRuntime(payload.runtime);
  const options = { runtime };
  if (runtime === "cloud") {
    if (cleanString(payload.api_key)) options.apiKey = cleanString(payload.api_key);
    if (payload.include_archived !== undefined) options.includeArchived = Boolean(payload.include_archived);
  } else if (cleanString(payload.project_path)) {
    options.cwd = cleanString(payload.project_path);
  }
  if (payload.limit !== undefined) options.limit = Number(payload.limit);
  if (cleanString(payload.cursor)) options.cursor = cleanString(payload.cursor);
  return options;
}

function cursorRequestOptions(payload) {
  const apiKey = cleanString(payload.api_key);
  return apiKey ? { apiKey } : {};
}

function normalizeRuntime(value) {
  return cleanString(value).toLowerCase() === "cloud" ? "cloud" : "local";
}

function publicModel(model) {
  if (!model) return undefined;
  return safeClone(model);
}

function safeClone(value) {
  if (value === undefined) return undefined;
  try {
    return JSON.parse(JSON.stringify(value));
  } catch {
    return String(value);
  }
}

function arrayOfStrings(value, fallback) {
  if (!Array.isArray(value)) return fallback;
  const clean = value.map((item) => cleanString(item)).filter(Boolean);
  return clean.length ? clean : fallback;
}

async function loadCursorSdk() {
  try {
    return await import("@cursor/sdk");
  } catch (firstError) {
    const nodeModules = cleanString(process.env.HERMES_CURSOR_HARNESS_SDK_NODE_MODULES);
    if (!nodeModules) throw firstError;
    const require = createRequire(path.join(nodeModules, "package.json"));
    return require("@cursor/sdk");
  }
}

function sdkVersion() {
  const nodeModules = cleanString(process.env.HERMES_CURSOR_HARNESS_SDK_NODE_MODULES);
  const candidates = [];
  if (nodeModules) candidates.push(path.join(nodeModules, "@cursor", "sdk", "package.json"));
  candidates.push(path.join(process.cwd(), "node_modules", "@cursor", "sdk", "package.json"));
  for (const candidate of candidates) {
    try {
      return JSON.parse(fs.readFileSync(candidate, "utf8")).version;
    } catch {}
  }
  return undefined;
}

async function readPayload() {
  const text = await new Promise((resolve, reject) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      data += chunk;
    });
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", reject);
  });
  const clean = String(text || "").trim();
  if (!clean) throw new Error("missing JSON payload on stdin");
  return JSON.parse(clean);
}

function emit(payload) {
  process.stdout.write(`${JSON.stringify(payload)}\n`);
}

function fatal(error) {
  if (fatalEmitted) return;
  fatalEmitted = true;
  emit({ type: "error", error: errorMessage(error), name: error?.name, stack: trimmedStack(error) });
  process.exitCode = 1;
  setTimeout(() => process.exit(1), 10);
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function errorMessage(error) {
  if (!error) return "unknown error";
  if (typeof error.message === "string" && error.message) return error.message;
  return String(error);
}

function trimmedStack(error) {
  if (!error || typeof error.stack !== "string") return undefined;
  return error.stack.split("\n").slice(0, 8).join("\n");
}

main();
