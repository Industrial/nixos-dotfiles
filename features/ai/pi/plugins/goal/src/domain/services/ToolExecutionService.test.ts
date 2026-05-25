/**
 * ToolExecutionService - BDD Tests
 *
 * Tests for Pi Agent tool execution within goal context.
 */
import { describe, it, expect } from "bun:test";
import { Effect } from "effect";
import { ToolExecutionService } from "./ToolExecutionService.js";
import { ToolExecutionServiceMock } from "./ToolExecutionServiceMock.js";

describe("ToolExecutionService", () => {
  const TestLayer = ToolExecutionServiceMock;

  describe("executeTool", () => {
    describe("Given read tool", () => {
      it("When executing read with file path, Then returns file contents", async () => {
        const program = Effect.gen(function* () {
          const service = yield* ToolExecutionService;
          return yield* service.executeTool("read", {
            path: "/test/file.txt",
          });
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.toolName).toBe("read");
        expect(result.isSuccess()).toBe(true);
        expect(result.output.length).toBeGreaterThan(0);
      });

      it("When executing read with invalid path, Then returns error", async () => {
        const program = Effect.gen(function* () {
          const service = yield* ToolExecutionService;
          return yield* service.executeTool("read", {
            path: "/nonexistent/file.txt",
          });
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.isFailure()).toBe(true);
        expect(result.hasError()).toBe(true);
      });
    });

    describe("Given write tool", () => {
      it("When executing write with content, Then writes successfully", async () => {
        const program = Effect.gen(function* () {
          const service = yield* ToolExecutionService;
          return yield* service.executeTool("write", {
            path: "/test/output.txt",
            content: "test content",
          });
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.toolName).toBe("write");
        expect(result.isSuccess()).toBe(true);
      });

      it("When executing write without content, Then returns error", async () => {
        const program = Effect.gen(function* () {
          const service = yield* ToolExecutionService;
          return yield* service.executeTool("write", {
            path: "/test/output.txt",
          });
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.isFailure()).toBe(true);
        expect(result.getErrorMessage()).toContain("content");
      });
    });

    describe("Given edit tool", () => {
      it("When executing edit with valid pattern, Then edits successfully", async () => {
        const program = Effect.gen(function* () {
          const service = yield* ToolExecutionService;
          return yield* service.executeTool("edit", {
            path: "/test/file.txt",
            oldString: "old",
            newString: "new",
          });
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.toolName).toBe("edit");
        expect(result.isSuccess()).toBe(true);
      });

      it("When executing edit with missing pattern, Then returns error", async () => {
        const program = Effect.gen(function* () {
          const service = yield* ToolExecutionService;
          return yield* service.executeTool("edit", {
            path: "/test/file.txt",
            oldString: "nonexistent",
            newString: "new",
          });
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.isFailure()).toBe(true);
        expect(result.getErrorMessage()).toContain("not found");
      });
    });

    describe("Given bash tool", () => {
      it("When executing bash command, Then returns command output", async () => {
        const program = Effect.gen(function* () {
          const service = yield* ToolExecutionService;
          return yield* service.executeTool("bash", {
            command: "echo 'hello'",
          });
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.toolName).toBe("bash");
        expect(result.isSuccess()).toBe(true);
        expect(result.output).toContain("hello");
      });

      it("When executing bash with failing command, Then returns error", async () => {
        const program = Effect.gen(function* () {
          const service = yield* ToolExecutionService;
          return yield* service.executeTool("bash", {
            command: "exit 1",
          });
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.isFailure()).toBe(true);
        expect(result.metadata?.exitCode).toBe(1);
      });
    });

    describe("Given unknown tool", () => {
      it("When executing unknown tool, Then returns error", async () => {
        const program = Effect.gen(function* () {
          const service = yield* ToolExecutionService;
          return yield* service.executeTool("unknown-tool", {});
        });

        const result = await Effect.runPromise(
          program.pipe(Effect.provide(TestLayer))
        );

        expect(result.isFailure()).toBe(true);
        expect(result.getErrorMessage()).toContain("Unknown tool");
      });
    });
  });

  describe("getAvailableTools", () => {
    it("When querying available tools, Then returns tool list", async () => {
      const program = Effect.gen(function* () {
        const service = yield* ToolExecutionService;
        return yield* service.getAvailableTools();
      });

      const tools = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(tools).toBeDefined();
      expect(Array.isArray(tools)).toBe(true);
      expect(tools.length).toBeGreaterThan(0);
    });

    it("When querying available tools, Then includes core tools", async () => {
      const program = Effect.gen(function* () {
        const service = yield* ToolExecutionService;
        return yield* service.getAvailableTools();
      });

      const tools = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      const toolNames = tools.map((t) => t.name);
      expect(toolNames).toContain("read");
      expect(toolNames).toContain("write");
      expect(toolNames).toContain("edit");
      expect(toolNames).toContain("bash");
    });

    it("When querying available tools, Then each tool has description", async () => {
      const program = Effect.gen(function* () {
        const service = yield* ToolExecutionService;
        return yield* service.getAvailableTools();
      });

      const tools = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      tools.forEach((tool) => {
        expect(tool.name).toBeDefined();
        expect(tool.description).toBeDefined();
        expect(tool.name.length).toBeGreaterThan(0);
        expect(tool.description.length).toBeGreaterThan(0);
      });
    });
  });

  describe("Tool execution timing", () => {
    it("When executing tool, Then result includes execution time", async () => {
      const program = Effect.gen(function* () {
        const service = yield* ToolExecutionService;
        return yield* service.executeTool("read", {
          path: "/test/file.txt",
        });
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(result.executionTimeMs).toBeGreaterThanOrEqual(0);
      expect(typeof result.executionTimeMs).toBe("number");
    });

    it("When executing multiple tools, Then each has timing", async () => {
      const program = Effect.gen(function* () {
        const service = yield* ToolExecutionService;
        const read = yield* service.executeTool("read", { path: "/test/a.txt" });
        const write = yield* service.executeTool("write", {
          path: "/test/b.txt",
          content: "data",
        });
        return { read, write };
      });

      const { read, write } = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(read.executionTimeMs).toBeGreaterThanOrEqual(0);
      expect(write.executionTimeMs).toBeGreaterThanOrEqual(0);
    });
  });

  describe("Tool result metadata", () => {
    it("When executing bash tool, Then metadata includes exit code", async () => {
      const program = Effect.gen(function* () {
        const service = yield* ToolExecutionService;
        return yield* service.executeTool("bash", {
          command: "echo test",
        });
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      expect(result.metadata).toBeDefined();
      expect(result.metadata?.exitCode).toBeDefined();
    });

    it("When executing read tool, Then metadata may include file stats", async () => {
      const program = Effect.gen(function* () {
        const service = yield* ToolExecutionService;
        return yield* service.executeTool("read", {
          path: "/test/file.txt",
        });
      });

      const result = await Effect.runPromise(
        program.pipe(Effect.provide(TestLayer))
      );

      // Metadata is optional but if present should be an object
      if (result.metadata) {
        expect(typeof result.metadata).toBe("object");
      }
    });
  });
});
