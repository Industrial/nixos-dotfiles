/**
 * Execution constants - BDD Tests
 */
import { describe, it, expect } from "bun:test";
import {
  MAX_GOAL_TURNS_LIFETIME,
  computeMaxTurnsThisCall,
  normalizeMaxTurnsPerCall,
} from "./constants.js";

describe("execution constants", () => {
  describe("normalizeMaxTurnsPerCall", () => {
    it("When maxTurns is omitted, Then defaults to 1", () => {
      expect(normalizeMaxTurnsPerCall(undefined)).toBe(1);
    });

    it("When maxTurns is 1000, Then accepts lifetime cap", () => {
      expect(normalizeMaxTurnsPerCall(1000)).toBe(1000);
    });

    it("When maxTurns exceeds lifetime cap, Then validation fails", () => {
      expect(() => normalizeMaxTurnsPerCall(MAX_GOAL_TURNS_LIFETIME + 1)).toThrow(
        /cannot exceed/
      );
    });
  });

  describe("computeMaxTurnsThisCall", () => {
    it("When cumulative is 0 and requested 1000, Then allows 1000 turns this call", () => {
      expect(computeMaxTurnsThisCall(1000, 0)).toBe(1000);
    });

    it("When cumulative is 998 and requested 1000, Then clamps to 2 remaining turns", () => {
      expect(computeMaxTurnsThisCall(1000, 998)).toBe(2);
    });

    it("When cumulative already at lifetime cap, Then returns 0", () => {
      expect(computeMaxTurnsThisCall(1000, MAX_GOAL_TURNS_LIFETIME)).toBe(0);
    });
  });
});
