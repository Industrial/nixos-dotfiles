/**
 * DatabaseSchema - BDD Tests
 *
 * Tests database schema initialization and helper functions.
 */
import { describe, it, expect } from "bun:test";
import { getDbPath, initializeSchema } from "./DatabaseSchema.js";
import * as path from "node:path";
import * as os from "node:os";

describe("DatabaseSchema", () => {
  describe("getDbPath", () => {
    describe("Given system environment", () => {
      it("When getting database path, Then returns path in home directory", () => {
        const dbPath = getDbPath();

        expect(dbPath).toBeDefined();
        expect(typeof dbPath).toBe("string");
        expect(dbPath.length).toBeGreaterThan(0);
      });

      it("When getting database path, Then path includes .dotfiles directory", () => {
        const dbPath = getDbPath();

        expect(dbPath).toContain(".dotfiles");
      });

      it("When getting database path, Then path includes .pi-data directory", () => {
        const dbPath = getDbPath();

        expect(dbPath).toContain(".pi-data");
      });

      it("When getting database path, Then filename is goals.db", () => {
        const dbPath = getDbPath();
        const filename = path.basename(dbPath);

        expect(filename).toBe("goals.db");
      });

      it("When getting database path, Then path is in user's home directory", () => {
        const dbPath = getDbPath();
        const homeDir = os.homedir();

        expect(dbPath).toContain(homeDir);
      });

      it("When getting database path multiple times, Then returns same path", () => {
        const path1 = getDbPath();
        const path2 = getDbPath();
        const path3 = getDbPath();

        expect(path1).toBe(path2);
        expect(path2).toBe(path3);
      });

      it("When getting database path, Then path is absolute", () => {
        const dbPath = getDbPath();

        expect(path.isAbsolute(dbPath)).toBe(true);
      });
    });

    describe("Path structure validation", () => {
      it("When checking path components, Then contains expected structure", () => {
        const dbPath = getDbPath();
        const homeDir = os.homedir();
        const expectedPath = path.join(homeDir, ".dotfiles", ".pi-data", "goals.db");

        expect(dbPath).toBe(expectedPath);
      });

      it("When getting directory name, Then points to .pi-data", () => {
        const dbPath = getDbPath();
        const dirName = path.dirname(dbPath);

        expect(dirName).toContain(".pi-data");
      });

      it("When checking file extension, Then has .db extension", () => {
        const dbPath = getDbPath();
        const ext = path.extname(dbPath);

        expect(ext).toBe(".db");
      });
    });
  });

  describe("initializeSchema", () => {
    describe("Schema function properties", () => {
      it("When checking initializeSchema, Then function is defined", () => {
        expect(initializeSchema).toBeDefined();
        expect(typeof initializeSchema).toBe("function");
      });

      it("When checking function name, Then name is correct", () => {
        expect(initializeSchema.name).toBe("initializeSchema");
      });

      it("When calling with mock SQL client, Then returns Effect", () => {
        const mockSql = {} as any;
        const result = initializeSchema(mockSql);

        expect(result).toBeDefined();
        expect(typeof result).toBe("object");
      });
    });

    describe("Function signature", () => {
      it("When checking function length, Then accepts one parameter", () => {
        expect(initializeSchema.length).toBe(1);
      });
    });
  });

  describe("Path construction", () => {
    it("When constructing paths, Then uses platform-specific separators", () => {
      const dbPath = getDbPath();
      const separator = path.sep;

      expect(dbPath).toContain(separator);
    });

    it("When checking path validity, Then path is valid on current platform", () => {
      const dbPath = getDbPath();

      // Path should not contain invalid characters
      expect(dbPath).not.toContain("\0");
      expect(dbPath.length).toBeGreaterThan(0);
    });
  });

  describe("Directory structure", () => {
    it("When analyzing path, Then has correct nesting depth", () => {
      const dbPath = getDbPath();
      const parts = dbPath.split(path.sep).filter(p => p.length > 0);

      // Should have at least: home, .dotfiles, .pi-data, goals.db
      expect(parts.length).toBeGreaterThan(3);
    });

    it("When checking parent directory, Then .dotfiles is parent of .pi-data", () => {
      const dbPath = getDbPath();
      const homeDir = os.homedir();
      const relativePath = path.relative(homeDir, dbPath);

      expect(relativePath).toMatch(/\.dotfiles.*\.pi-data/);
    });
  });

  describe("Cross-platform compatibility", () => {
    it("When running on any platform, Then path is generated", () => {
      const dbPath = getDbPath();

      expect(dbPath).toBeTruthy();
      expect(typeof dbPath).toBe("string");
    });

    it("When checking platform compatibility, Then uses os.homedir()", () => {
      const dbPath = getDbPath();
      const homeDir = os.homedir();

      expect(dbPath.startsWith(homeDir)).toBe(true);
    });
  });

  describe("Idempotency", () => {
    it("When calling getDbPath repeatedly, Then always returns same result", () => {
      const results = new Set<string>();

      for (let i = 0; i < 100; i++) {
        results.add(getDbPath());
      }

      expect(results.size).toBe(1);
    });

    it("When calling in sequence, Then results are consistent", () => {
      const calls = Array.from({ length: 10 }, () => getDbPath());
      const allSame = calls.every(p => p === calls[0]);

      expect(allSame).toBe(true);
    });
  });
});
