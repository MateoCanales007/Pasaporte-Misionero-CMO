import {strict as assert} from "node:assert";
import {describe, it} from "node:test";
import {parseLoginRenames} from "../src/migrations/renameLogins";

describe("parseLoginRenames", () => {
  it("sin lista no hay cambios", () => {
    assert.deepEqual(parseLoginRenames(undefined), []);
    assert.deepEqual(parseLoginRenames(null), []);
  });

  it("normaliza correo y usuario", () => {
    const input = [{fromEmail: " Ana@Gmail.com ", username: "Ana.M"}];
    assert.deepEqual(
      parseLoginRenames(input),
      [{fromEmail: "ana@gmail.com", username: "ana.m"}],
    );
  });

  it("rechaza @cmo.com, usuarios inválidos o repetidos", () => {
    const bad = (fromEmail: string, username: string) =>
      () => parseLoginRenames([{fromEmail, username}]);
    assert.throws(bad("x@cmo.com", "xx1"));
    assert.throws(bad("x@gmail.com", "a b"));
    assert.throws(bad("no-es-correo", "abc"));
    assert.throws(() => parseLoginRenames([
      {fromEmail: "a@gmail.com", username: "abc"},
      {fromEmail: "b@gmail.com", username: "abc"},
    ]));
    assert.throws(() => parseLoginRenames("abc"));
  });
});
