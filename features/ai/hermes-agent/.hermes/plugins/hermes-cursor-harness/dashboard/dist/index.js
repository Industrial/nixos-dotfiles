(function () {
  "use strict";

  const SDK = window.__HERMES_PLUGIN_SDK__;
  const { React } = SDK;
  const { useEffect, useMemo, useState } = SDK.hooks;
  const { Card, CardContent, CardHeader, CardTitle, Badge, Button, Input, Label, Separator } = SDK.components;
  const BASE = "/api/plugins/hermes-cursor-harness";

  function pretty(value) {
    return JSON.stringify(value, null, 2);
  }

  function statusBadge(ok, label) {
    return React.createElement(Badge, { variant: ok ? "default" : "outline" }, label || (ok ? "online" : "offline"));
  }

  function Field(props) {
    return React.createElement("div", { className: "flex flex-col gap-1" },
      React.createElement("span", { className: "text-[11px] uppercase tracking-wide text-muted-foreground" }, props.label),
      React.createElement("span", { className: "font-courier text-sm break-all" }, props.value || "none"),
    );
  }

  function StatCard(props) {
    return React.createElement(Card, null,
      React.createElement(CardHeader, { className: "pb-2" },
        React.createElement("div", { className: "flex items-center justify-between gap-3" },
          React.createElement(CardTitle, { className: "text-sm" }, props.title),
          props.badge,
        ),
      ),
      React.createElement(CardContent, { className: "grid gap-3" }, props.children),
    );
  }

  function CursorHarnessPage() {
    const [summary, setSummary] = useState(null);
    const [models, setModels] = useState(null);
    const [demo, setDemo] = useState(null);
    const [loading, setLoading] = useState(false);
    const [demoLoading, setDemoLoading] = useState(false);
    const [project, setProject] = useState("");
    const [prompt, setPrompt] = useState("");
    const [error, setError] = useState("");

    function refresh() {
      setLoading(true);
      setError("");
      Promise.all([
        SDK.fetchJSON(BASE + "/summary"),
        SDK.fetchJSON(BASE + "/models"),
      ])
        .then(function (values) {
          setSummary(values[0]);
          setModels(values[1]);
          const projects = values[0]?.doctor?.projects || {};
          const firstProject = Object.values(projects)[0] || "";
          setProject(function (current) { return current || firstProject; });
        })
        .catch(function (err) { setError(String(err && err.message ? err.message : err)); })
        .finally(function () { setLoading(false); });
    }

    function runDemo() {
      setDemoLoading(true);
      setError("");
      SDK.fetchJSON(BASE + "/demo", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          project: project || undefined,
          prompt: prompt || undefined,
          token: "HCH_UI_DEMO_OK",
          transport: "sdk",
        }),
      })
        .then(function (data) { setDemo(data); return SDK.fetchJSON(BASE + "/summary"); })
        .then(function (data) { setSummary(data); })
        .catch(function (err) { setError(String(err && err.message ? err.message : err)); })
        .finally(function () { setDemoLoading(false); });
    }

    useEffect(function () {
      refresh();
    }, []);

    const doctor = summary?.doctor || {};
    const latest = summary?.latest_session || {};
    const apiKey = summary?.api_key || {};
    const background = summary?.background || {};
    const proposalInbox = summary?.proposal_inbox || {};
    const modelList = models?.sample || [];
    const modelText = useMemo(function () {
      if (!modelList.length) return "No model list loaded yet.";
      return modelList.map(function (item) { return item.id; }).join(", ");
    }, [models]);

    return React.createElement("div", { className: "flex flex-col gap-6" },
      React.createElement("div", { className: "flex flex-col gap-3 md:flex-row md:items-start md:justify-between" },
        React.createElement("div", { className: "flex flex-col gap-2" },
          React.createElement("div", { className: "flex items-center gap-3" },
            React.createElement("h2", { className: "font-mondwest text-xl uppercase tracking-wide" }, "Cursor Harness"),
            statusBadge(Boolean(doctor.success), doctor.success ? "connected" : "needs setup"),
          ),
          React.createElement("p", { className: "max-w-3xl text-sm text-muted-foreground" },
            "Hermes owns the dashboard and session control. Cursor owns the coding-agent run. This tab proves the harness path live through SDK, ACP, stream, proposals, and Background Agents.",
          ),
        ),
        React.createElement("div", { className: "flex items-center gap-2" },
          React.createElement(Button, { onClick: refresh, disabled: loading }, loading ? "Refreshing" : "Refresh"),
          React.createElement(Button, { onClick: runDemo, disabled: demoLoading || !doctor.sdk_available }, demoLoading ? "Running Cursor" : "Run SDK Demo"),
        ),
      ),

      error && React.createElement(Card, { className: "border-destructive" },
        React.createElement(CardContent, { className: "py-3 text-sm text-destructive" }, error),
      ),

      React.createElement("div", { className: "grid gap-4 xl:grid-cols-4 md:grid-cols-2" },
        React.createElement(StatCard, { title: "Cursor SDK", badge: statusBadge(Boolean(doctor.sdk_available)) },
          React.createElement(Field, { label: "Runtime", value: doctor.sdk_runtime }),
          React.createElement(Field, { label: "Version", value: summary?.sdk?.sdk_version || doctor.sdk_status?.sdk_version }),
          React.createElement(Field, { label: "Models", value: models?.count ? String(models.count) : "pending" }),
        ),
        React.createElement(StatCard, { title: "Cursor Agent", badge: statusBadge(Boolean(doctor.acp_available && doctor.stream_available)) },
          React.createElement(Field, { label: "ACP", value: doctor.acp_available ? "available" : "missing" }),
          React.createElement(Field, { label: "Stream JSON", value: doctor.stream_available ? "available" : "missing" }),
          React.createElement(Field, { label: "Transport", value: doctor.transport }),
        ),
        React.createElement(StatCard, { title: "API Key", badge: statusBadge(Boolean(apiKey.available)) },
          React.createElement(Field, { label: "Source", value: apiKey.source }),
          React.createElement(Field, { label: "Fingerprint", value: apiKey.fingerprint }),
          React.createElement(Field, { label: "Background Agents", value: background.success ? "reachable" : "not reachable" }),
        ),
        React.createElement(StatCard, { title: "Hermes State", badge: statusBadge(Boolean(latest.harness_session_id), latest.status || "idle") },
          React.createElement(Field, { label: "Sessions", value: String(summary?.session_count ?? 0) }),
          React.createElement(Field, { label: "Latest Transport", value: latest.transport }),
          React.createElement(Field, { label: "Proposals", value: String(proposalInbox?.counts?.pending ?? 0) + " pending" }),
        ),
      ),

      React.createElement(Card, null,
        React.createElement(CardHeader, null,
          React.createElement(CardTitle, { className: "text-base" }, "Live Cursor SDK Demo"),
        ),
        React.createElement(CardContent, { className: "grid gap-4" },
          React.createElement("div", { className: "grid gap-3 md:grid-cols-2" },
            React.createElement("div", { className: "grid gap-1" },
              React.createElement(Label, null, "Project path"),
              React.createElement(Input, {
                value: project,
                onChange: function (event) { setProject(event.target.value); },
                placeholder: "Hermes project alias or absolute path",
              }),
            ),
            React.createElement("div", { className: "grid gap-1" },
              React.createElement(Label, null, "Prompt override"),
              React.createElement(Input, {
                value: prompt,
                onChange: function (event) { setPrompt(event.target.value); },
                placeholder: "Optional read-only prompt",
              }),
            ),
          ),
          demo && React.createElement("div", { className: "grid gap-3 rounded-sm border border-border bg-background/30 p-4" },
            React.createElement("div", { className: "flex flex-wrap items-center gap-2" },
              statusBadge(Boolean(demo.success), demo.success ? "success" : "failed"),
              statusBadge(Boolean(demo.token_seen), demo.token_seen ? "token seen" : "token missing"),
              React.createElement(Badge, { variant: "outline" }, demo.transport || "unknown"),
              React.createElement(Badge, { variant: "outline" }, (demo.modified_files || []).length + " modified files"),
            ),
            React.createElement("div", { className: "grid gap-3 md:grid-cols-3" },
              React.createElement(Field, { label: "Harness session", value: demo.harness_session_id }),
              React.createElement(Field, { label: "Cursor session", value: demo.cursor_session_id }),
              React.createElement(Field, { label: "SDK run", value: demo.sdk_run_id }),
            ),
            React.createElement("pre", { className: "max-h-56 overflow-auto whitespace-pre-wrap rounded-sm border border-border bg-black/30 p-3 font-courier text-xs text-muted-foreground" }, demo.text || demo.error || "No output"),
          ),
        ),
      ),

      React.createElement("div", { className: "grid gap-4 xl:grid-cols-2" },
        React.createElement(Card, null,
          React.createElement(CardHeader, null, React.createElement(CardTitle, { className: "text-base" }, "Cursor Model Catalog")),
          React.createElement(CardContent, { className: "grid gap-3" },
            React.createElement("p", { className: "font-courier text-sm text-muted-foreground break-words" }, modelText),
            models?.error && React.createElement("p", { className: "text-sm text-destructive" }, models.error),
          ),
        ),
        React.createElement(Card, null,
          React.createElement(CardHeader, null, React.createElement(CardTitle, { className: "text-base" }, "Latest Harness Session")),
          React.createElement(CardContent, { className: "grid gap-3" },
            React.createElement("div", { className: "grid gap-3 md:grid-cols-2" },
              React.createElement(Field, { label: "Harness session", value: latest.harness_session_id }),
              React.createElement(Field, { label: "Cursor session", value: latest.cursor_session_id }),
              React.createElement(Field, { label: "Mode", value: latest.mode }),
              React.createElement(Field, { label: "Status", value: latest.status }),
            ),
            React.createElement(Separator, null),
            React.createElement("pre", { className: "max-h-52 overflow-auto whitespace-pre-wrap rounded-sm border border-border bg-black/30 p-3 font-courier text-xs text-muted-foreground" }, latest.last_result || "No session result yet."),
          ),
        ),
      ),
    );
  }

  window.__HERMES_PLUGINS__.register("hermes-cursor-harness", CursorHarnessPage);
})();
