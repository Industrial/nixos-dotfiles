/**
 * GoalApplicationService Interface - Type Tests
 *
 * Verifies the application service interface contract.
 */
import { describe, it, expect } from "bun:test";
import { GoalApplicationService } from "./GoalApplicationService.js";

describe("GoalApplicationService", () => {
  describe("Interface contract", () => {
    it("When importing GoalApplicationService, Then interface is defined", () => {
      expect(GoalApplicationService).toBeDefined();
      expect(typeof GoalApplicationService).toBe("function");
    });

    it("When checking interface name, Then name matches", () => {
      expect(GoalApplicationService.name).toBe("GoalApplicationService");
    });

    it("When checking interface key, Then key is defined", () => {
      expect(GoalApplicationService.key).toBeDefined();
      expect(typeof GoalApplicationService.key).toBe("string");
      expect(GoalApplicationService.key).toBe("GoalApplicationService");
    });
  });

  describe("Type safety", () => {
    it("When using as a Context tag, Then type is correct", () => {
      const tag = GoalApplicationService;
      expect(tag).toBe(GoalApplicationService);
    });

    it("When checking static methods, Then of method exists", () => {
      expect(GoalApplicationService.of).toBeDefined();
      expect(typeof GoalApplicationService.of).toBe("function");
    });
  });
});
