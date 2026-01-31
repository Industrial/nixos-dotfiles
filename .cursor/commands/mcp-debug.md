Use the MCP Debug Server like so:

```
// 1. Create session with BunJS
const session = await create_debug_session({
  language: "javascript",
  name: "risk-calculator-bun-debug",
  executablePath: "bun"
});

// 2. Set breakpoints (on executable lines)
await set_breakpoint({
  sessionId: session.id,
  file: "src/application/services/CalculateRiskUseCase.ts",
  line: 50 // executable line number
});

// 3. Start debugging
await start_debugging({
  sessionId: session.id,
  scriptPath: "src/main.ts"
});

// 4. Debug interactively
await step_over({ sessionId: session.id });
await get_local_variables({ sessionId: session.id });
await evaluate_expression({ 
  sessionId: session.id, 
  expression: "someVariable.value" 
});
```
