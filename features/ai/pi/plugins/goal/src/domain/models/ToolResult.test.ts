/**
 * ToolResult - Domain Model Tests
 *
 * Tests for tool execution results from Pi Agent's tooling system.
 */
import { describe, it, expect } from "bun:test";
import { ToolResult } from "./ToolResult.js";

describe("ToolResult", () => {
  describe("Schema Validation", () => {
    describe("Given valid tool result data", () => {
      it("When creating successful result, Then result is created", () => {
        const result = new ToolResult({
          toolName: "read",
          success: true,
          output: "file contents",
          executionTimeMs: 42,
          timestamp: Date.now(),
        });

        expect(result.toolName).toBe("read");
        expect(result.success).toBe(true);
        expect(result.output).toBe("file contents");
        expect(result.executionTimeMs).toBe(42);
      });

      it("When creating failed result, Then result is created with error", () => {
        const result = new ToolResult({
          toolName: "write",
          success: false,
          output: "",
          error: "Permission denied",
          executionTimeMs: 10,
          timestamp: Date.now(),
        });

        expect(result.success).toBe(false);
        expect(result.error).toBe("Permission denied");
      });

      it("When creating result with metadata, Then metadata is stored", () => {
        const result = new ToolResult({
          toolName: "bash",
          success: true,
          output: "command output",
          executionTimeMs: 100,
          metadata: { exitCode: 0, workingDir: "/tmp" },
          timestamp: Date.now(),
        });

        expect(result.metadata).toBeDefined();
        expect(result.metadata?.exitCode).toBe(0);
        expect(result.metadata?.workingDir).toBe("/tmp");
      });
    });

    describe("Given invalid tool result data", () => {
      it("When creating result without toolName, Then validation fails", () => {
        expect(() => {
          new ToolResult({
            success: true,
            output: "test",
            executionTimeMs: 10,
            timestamp: Date.now(),
          } as any);
        }).toThrow();
      });

      it("When creating result with empty toolName, Then validation fails", () => {
        expect(() => {
          new ToolResult({
            toolName: "",
            success: true,
            output: "test",
            executionTimeMs: 10,
            timestamp: Date.now(),
          });
        }).toThrow();
      });

      it("When creating result without success flag, Then validation fails", () => {
        expect(() => {
          new ToolResult({
            toolName: "read",
            output: "test",
            executionTimeMs: 10,
            timestamp: Date.now(),
          } as any);
        }).toThrow();
      });

      it("When creating result with negative executionTimeMs, Then validation fails", () => {
        expect(() => {
          new ToolResult({
            toolName: "read",
            success: true,
            output: "test",
            executionTimeMs: -1,
            timestamp: Date.now(),
          });
        }).toThrow();
      });

      it("When creating result without timestamp, Then validation fails", () => {
        expect(() => {
          new ToolResult({
            toolName: "read",
            success: true,
            output: "test",
            executionTimeMs: 10,
          } as any);
        }).toThrow();
      });
    });
  });

  describe("Helper methods", () => {
    describe("isSuccess", () => {
      it("When result is successful, Then returns true", () => {
        const result = new ToolResult({
          toolName: "read",
          success: true,
          output: "data",
          executionTimeMs: 10,
          timestamp: Date.now(),
        });

        expect(result.isSuccess()).toBe(true);
      });

      it("When result is failure, Then returns false", () => {
        const result = new ToolResult({
          toolName: "read",
          success: false,
          output: "",
          error: "Failed",
          executionTimeMs: 10,
          timestamp: Date.now(),
        });

        expect(result.isSuccess()).toBe(false);
      });
    });

    describe("isFailure", () => {
      it("When result is successful, Then returns false", () => {
        const result = new ToolResult({
          toolName: "read",
          success: true,
          output: "data",
          executionTimeMs: 10,
          timestamp: Date.now(),
        });

        expect(result.isFailure()).toBe(false);
      });

      it("When result is failure, Then returns true", () => {
        const result = new ToolResult({
          toolName: "read",
          success: false,
          output: "",
          error: "Failed",
          executionTimeMs: 10,
          timestamp: Date.now(),
        });

        expect(result.isFailure()).toBe(true);
      });
    });

    describe("hasError", () => {
      it("When result has no error, Then returns false", () => {
        const result = new ToolResult({
          toolName: "read",
          success: true,
          output: "data",
          executionTimeMs: 10,
          timestamp: Date.now(),
        });

        expect(result.hasError()).toBe(false);
      });

      it("When result has error, Then returns true", () => {
        const result = new ToolResult({
          toolName: "read",
          success: false,
          output: "",
          error: "Something went wrong",
          executionTimeMs: 10,
          timestamp: Date.now(),
        });

        expect(result.hasError()).toBe(true);
      });

      it("When result has empty error string, Then returns false", () => {
        const result = new ToolResult({
          toolName: "read",
          success: true,
          output: "data",
          error: "",
          executionTimeMs: 10,
          timestamp: Date.now(),
        });

        expect(result.hasError()).toBe(false);
      });
    });

    describe("getErrorMessage", () => {
      it("When result has error, Then returns error message", () => {
        const result = new ToolResult({
          toolName: "write",
          success: false,
          output: "",
          error: "Permission denied",
          executionTimeMs: 10,
          timestamp: Date.now(),
        });

        expect(result.getErrorMessage()).toBe("Permission denied");
      });

      it("When result has no error, Then returns undefined", () => {
        const result = new ToolResult({
          toolName: "read",
          success: true,
          output: "data",
          executionTimeMs: 10,
          timestamp: Date.now(),
        });

        expect(result.getErrorMessage()).toBeUndefined();
      });
    });
  });

  describe("Tool-specific results", () => {
    it("When read tool succeeds, Then output contains file data", () => {
      const result = new ToolResult({
        toolName: "read",
        success: true,
        output: "file content here",
        executionTimeMs: 25,
        timestamp: Date.now(),
      });

      expect(result.toolName).toBe("read");
      expect(result.output).toContain("file content");
    });

    it("When write tool succeeds, Then output confirms write", () => {
      const result = new ToolResult({
        toolName: "write",
        success: true,
        output: "File written successfully",
        executionTimeMs: 50,
        timestamp: Date.now(),
      });

      expect(result.toolName).toBe("write");
      expect(result.isSuccess()).toBe(true);
    });

    it("When bash tool executes, Then metadata includes exit code", () => {
      const result = new ToolResult({
        toolName: "bash",
        success: true,
        output: "ls output",
        executionTimeMs: 75,
        metadata: { exitCode: 0, stderr: "" },
        timestamp: Date.now(),
      });

      expect(result.metadata?.exitCode).toBe(0);
    });

    it("When edit tool fails, Then error explains failure", () => {
      const result = new ToolResult({
        toolName: "edit",
        success: false,
        output: "",
        error: "Pattern not found in file",
        executionTimeMs: 30,
        timestamp: Date.now(),
      });

      expect(result.toolName).toBe("edit");
      expect(result.getErrorMessage()).toContain("Pattern not found");
    });
  });
});
