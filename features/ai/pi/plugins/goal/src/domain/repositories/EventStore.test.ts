/**
 * EventStore Interface - Type Tests
 *
 * Verifies the event store interface contract.
 */
import { describe, it, expect } from "bun:test";
import { EventStore } from "./EventStore.js";

describe("EventStore", () => {
  describe("Interface contract", () => {
    it("When importing EventStore, Then interface is defined", () => {
      expect(EventStore).toBeDefined();
      expect(typeof EventStore).toBe("function");
    });

    it("When checking interface name, Then name matches", () => {
      expect(EventStore.name).toBe("Tag");
    });

    it("When checking interface key, Then key is defined", () => {
      expect(EventStore.key).toBeDefined();
      expect(typeof EventStore.key).toBe("string");
      expect(EventStore.key).toBe("EventStore");
    });
  });

  describe("Type safety", () => {
    it("When using as a Context tag, Then type is correct", () => {
      const tag = EventStore;
      expect(tag).toBe(EventStore);
    });

    it("When checking static methods, Then of method exists", () => {
      expect(EventStore.of).toBeDefined();
      expect(typeof EventStore.of).toBe("function");
    });
  });
});
