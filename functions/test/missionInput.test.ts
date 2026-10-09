import assert from "node:assert/strict";
import {describe, test} from "node:test";
import {ValidationError} from "../src/core/errors";
import {parseMissionInput} from "../src/missions/missionInput";
import {HOUR, T0} from "./support/fakes";

const valid = {
  name: "  Misión Apopa ",
  isoCode: " sv ",
  image: "",
  location: {lat: 13.8, lng: -89.18},
  placeId: "ChIJ-abc_123",
  schedules: [
    {start: T0 + 2 * HOUR, end: T0 + 3 * HOUR},
    {start: T0, end: T0 + HOUR},
  ],
  status: "active",
};

/**
 * @param {object} data Entrada.
 * @param {string} field Campo esperado en el error.
 */
function assertField(data: unknown, field: string) {
  assert.throws(() => parseMissionInput(data), (error: unknown) => {
    assert.ok(error instanceof ValidationError, String(error));
    assert.equal(error.field, field);
    return true;
  });
}

describe("parseMissionInput", () => {
  test("normaliza una entrada válida", () => {
    assert.deepEqual(parseMissionInput(valid), {
      missionId: null,
      name: "Misión Apopa",
      isoCode: "SV",
      image: "",
      location: {lat: 13.8, lng: -89.18},
      placeId: "ChIJ-abc_123",
      schedules: [
        {startMs: T0, endMs: T0 + HOUR},
        {startMs: T0 + 2 * HOUR, endMs: T0 + 3 * HOUR},
      ],
      status: "active",
    });
  });

  test("campos opcionales", () => {
    const result = parseMissionInput({
      ...valid,
      missionId: "abc123",
      placeId: null,
      image: "https://example.com/a.png",
    });
    assert.equal(result.missionId, "abc123");
    assert.equal(result.placeId, null);
    assert.equal(parseMissionInput({...valid, placeId: ""}).placeId, null);
  });

  test("borrador puede no tener horarios; activa no", () => {
    assert.deepEqual(
      parseMissionInput({...valid, status: "draft", schedules: []}).schedules,
      [],
    );
    assertField({...valid, schedules: []}, "schedules");
  });

  test("errores por campo", () => {
    assertField({...valid, name: "A"}, "name");
    assertField({...valid, name: "x".repeat(81)}, "name");
    assertField({...valid, isoCode: "S"}, "isoCode");
    assertField({...valid, isoCode: "SV1"}, "isoCode");
    assertField({...valid, isoCode: "ABCDEFG"}, "isoCode");
    assertField({...valid, image: "http://example.com/a.png"}, "image");
    assertField({...valid, image: "javascript:alert(1)"}, "image");
    assertField({...valid, image: 5}, "image");
    assertField({...valid, location: {lat: 91, lng: 0}}, "location");
    assertField({...valid, location: {lat: 0, lng: -181}}, "location");
    assertField({...valid, location: {lat: "13", lng: 0}}, "location");
    assertField({...valid, location: null}, "location");
    assertField({...valid, placeId: "bad id!"}, "placeId");
    assertField({...valid, status: "finished"}, "status");
    assertField({...valid, missionId: "a/b"}, "missionId");
    assertField({...valid, schedules: [{start: T0, end: T0}]}, "schedules");
    assertField("texto", "data");
  });
});
