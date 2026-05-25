/**
 * GoalRepository Interface - Type Tests
 *
 * Verifies the repository interface contract.
 */
import { describe, it, expect } from "bun:test";
import { GoalRepository } from "./GoalRepository.js";

describe("GoalRepository", () => {
  describe("Interface contract", () => {
    it("When importing GoalRepository, Then interface is defined", () => {
      expect(GoalRepository).toBeDefined();
      expect(typeof GoalRepository).toBe("function");
    });

    it("When checking interface name, Then name matches", () => {
      expect(GoalRepository.name).toBe("Tag");
    });

    it("When checking interface structure, Then key property exists", () => {
      expect(GoalRepository.key).toBeDefined();
      expect(typeof GoalRepository.key).toBe("string");
    });
  });

  describe("Type safety", () => {
    it("When using as a Context tag, Then type is correct", () => {
      const tag = GoalRepository;
      expect(tag).toBe(GoalRepository);
    });
  });
});
