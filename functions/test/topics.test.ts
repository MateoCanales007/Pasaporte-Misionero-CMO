import assert from "node:assert/strict";
import {describe, test} from "node:test";
import {
  ALL_TOPICS,
  sameTopics,
  topicActions,
  topicsForPrefs,
} from "../src/notifications/topics";

describe("topicsForPrefs", () => {
  test("sin preferencias → todos los temas", () => {
    const all = ["missions", "mission_reminders", "sermons"];
    assert.deepEqual([...ALL_TOPICS], all);
    for (const prefs of [undefined, null, {}, "x", 5, []]) {
      assert.deepEqual(topicsForPrefs(prefs), all);
    }
  });

  test("solo un false explícito desactiva", () => {
    assert.deepEqual(topicsForPrefs({newMission: false}), [
      "mission_reminders",
      "sermons",
    ]);
    assert.deepEqual(topicsForPrefs({missionReminder: false}), [
      "missions",
      "sermons",
    ]);
    assert.deepEqual(topicsForPrefs({newSermon: false}), [
      "missions",
      "mission_reminders",
    ]);
    assert.deepEqual(topicsForPrefs({
      newMission: false,
      missionReminder: false,
      newSermon: false,
    }), []);
    assert.deepEqual(topicsForPrefs({newMission: "false", newSermon: 0}), [
      "missions",
      "mission_reminders",
      "sermons",
    ]);
    assert.equal(topicsForPrefs({stampConfirmed: false}).length, 3);
  });

  test("topicActions separa suscribir y desuscribir", () => {
    assert.deepEqual(topicActions({newSermon: false}), {
      subscribe: ["missions", "mission_reminders"],
      unsubscribe: ["sermons"],
    });
    assert.deepEqual(topicActions(undefined).unsubscribe, []);
  });

  test("sameTopics ignora el orden", () => {
    assert.equal(sameTopics(["a", "b"], ["b", "a"]), true);
    assert.equal(sameTopics(["a"], ["a", "b"]), false);
  });
});
