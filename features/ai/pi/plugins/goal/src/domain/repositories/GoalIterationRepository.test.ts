/**
 * GoalIterationRepository Interface - Type Tests
 *
 * Verifies the repository interface contract.
 */
import { describe, it, expect } from "bun:test";
import { GoalIterationRepository } from "./GoalIterationRepository.js";

describe("GoalIterationRepository", () => {
  describe("Interface contract", () => {
    it("When importing GoalIterationRepository, Then interface is defined", () => {
      expect(GoalIterationRepository).toBeDefined();
      expect(typeof GoalIterationRepository).toBe("function");
    });

    it("When checking interface name, Then name matches", () => {
      expect(GoalIterationRepository.name).toBe("GoalIterationRepository");
    });

    it("When checking interface key, Then key is defined", () => {
      expect(GoalIterationRepository.key).toBeDefined();
      expect(typeof GoalIterationRepository.key).toBe("string");
      expect(GoalIterationRepository.key).toBe("GoalIterationRepository");
    });
  });

  describe("Type safety", () => {
    it("When using as a Context tag, Then type is correct", () => {
      const tag = GoalIterationRepository;
      expect(tag).toBe(GoalIterationRepository);
    });

    it("When checking static methods, Then of method exists", () => {
      expect(GoalIterationRepository.of).toBeDefined();
      expect(typeof GoalIterationRepository.of).toBe("function");
    });
  });
});
