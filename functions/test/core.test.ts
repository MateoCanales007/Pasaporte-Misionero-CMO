import assert from "node:assert/strict";
import {describe, test} from "node:test";
import {safeEqualStrings} from "../src/core/crypto";
import {ValidationError} from "../src/core/errors";
import {claimsWithRole, roleFromClaims} from "../src/core/roles";
import {isHttpsUrl, isValidDocId} from "../src/core/validation";
import {
  mergeReferences,
  parsePhotoReference,
  parsePhotoSource,
  parsePlaceId,
  parseQuery,
} from "../src/places/placesInput";

describe("roles", () => {
  test("roleFromClaims", () => {
    assert.equal(roleFromClaims({role: "admin"}), "admin");
    assert.equal(roleFromClaims({role: "qrPresenter"}), "qrPresenter");
    assert.equal(roleFromClaims({role: "user"}), null);
    assert.equal(roleFromClaims({role: "superadmin"}), null);
    assert.equal(roleFromClaims(undefined), null);
  });

  test("claimsWithRole conserva otros claims y quita role con 'user'", () => {
    assert.deepEqual(claimsWithRole({a: 1}, "qrPresenter"), {
      a: 1,
      role: "qrPresenter",
    });
    assert.deepEqual(claimsWithRole({a: 1, role: "qrPresenter"}, "user"), {
      a: 1,
    });
    assert.deepEqual(claimsWithRole(undefined, "user"), {});
  });
});

describe("validación y utilidades", () => {
  test("safeEqualStrings", () => {
    assert.equal(safeEqualStrings("token-123", "token-123"), true);
    assert.equal(safeEqualStrings("token-123", "token-124"), false);
    assert.equal(safeEqualStrings("token", "token-123"), false);
    assert.equal(safeEqualStrings("", ""), true);
  });

  test("isValidDocId", () => {
    assert.equal(isValidDocId("abc-123_X"), true);
    for (const bad of ["", "a/b", ".", "..", "__x__", 5, null]) {
      assert.equal(isValidDocId(bad), false);
    }
    assert.equal(isValidDocId("x".repeat(1501)), false);
  });

  test("isHttpsUrl", () => {
    assert.equal(isHttpsUrl("https://example.com/a.png"), true);
    assert.equal(isHttpsUrl("http://example.com"), false);
    assert.equal(isHttpsUrl("https://u:p@example.com"), false);
    assert.equal(isHttpsUrl("nada"), false);
    assert.equal(isHttpsUrl(`https://e.com/${"a".repeat(3000)}`), false);
  });
});

describe("entradas de Places", () => {
  const field = (fn: () => unknown, name: string) =>
    assert.throws(fn, (e: unknown) =>
      e instanceof ValidationError && e.field === name);

  test("query 1..120", () => {
    assert.equal(parseQuery({query: "  San Salvador "}), "San Salvador");
    field(() => parseQuery({query: "  "}), "query");
    field(() => parseQuery({query: "x".repeat(121)}), "query");
    field(() => parseQuery({}), "query");
  });

  test("placeId y photoReference", () => {
    assert.equal(parsePlaceId({placeId: "ChIJ_abc-1"}), "ChIJ_abc-1");
    field(() => parsePlaceId({placeId: "a b"}), "placeId");
    field(() => parsePlaceId({placeId: "x".repeat(513)}), "placeId");
    assert.equal(parsePhotoReference({photoReference: "abc"}), "abc");
    field(() => parsePhotoReference({photoReference: ""}), "photoReference");
    field(() => parsePhotoReference({photoReference: "x".repeat(2001)}),
      "photoReference");
  });

  test("getPhotoReferences: placeId primero, luego coordenadas", () => {
    assert.deepEqual(parsePhotoSource({placeId: "P1", lat: 1, lng: 2}), {
      kind: "place",
      placeId: "P1",
    });
    assert.deepEqual(parsePhotoSource({placeId: null, lat: 0, lng: 0}), {
      kind: "coords",
      lat: 0,
      lng: 0,
    });
    assert.deepEqual(parsePhotoSource({}), {kind: "none"});
    field(() => parsePhotoSource({lat: 95, lng: 0}), "location");
    field(() => parsePhotoSource({lat: "1", lng: 2}), "location");
    field(() => parsePhotoSource({placeId: "../x"}), "placeId");
  });
});

describe("mergeReferences (fotos del lugar)", () => {
  test("une sin repetir y respeta el máximo", () => {
    assert.deepEqual(
      mergeReferences([["a", "b"], ["b", "c", "d"]], 3),
      ["a", "b", "c"],
    );
    assert.deepEqual(mergeReferences([[], []]), []);
  });
});
