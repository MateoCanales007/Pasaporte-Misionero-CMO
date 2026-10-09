import assert from "node:assert/strict";
import {describe, test} from "node:test";
import {
  buildPublicProfile,
  initialsFor,
  resolveCellName,
  samePublicProfile,
} from "../src/profiles/publicProfile";
import {T0, ts} from "./support/fakes";

const privateDoc = {
  id: "u1",
  username: "anaperez",
  passportNumber: "PM-2024-0001",
  fullName: "  Ana   María Pérez ",
  nationality: "Salvadoreña",
  dateOfBirth: ts(T0 - 20 * 365 * 86_400_000),
  cellId: "celula-1",
  isAdmin: false,
  canShowQR: true,
  notificationPrefs: {newMission: false},
  stamps: [{stampId: "m1", dateObtained: ts(T0)}, {stampId: "m2"}],
};

const PUBLIC_KEYS = [
  "cellName",
  "communityVisible",
  "displayName",
  "initials",
  "nationality",
  "stampCount",
  "stampIds",
  "uid",
].sort();

describe("buildPublicProfile – privacidad", () => {
  test("solo publica los campos del contrato", () => {
    const profile = buildPublicProfile("u1", privateDoc, ["m3"], null);
    assert.deepEqual(Object.keys(profile).sort(), PUBLIC_KEYS);
    const json = JSON.stringify(profile);
    for (const secret of [
      "anaperez",
      "PM-2024-0001",
      "dateOfBirth",
      "username",
      "Salvadoreña",
    ]) {
      assert.ok(!json.includes(secret), `no debe incluir ${secret}`);
    }
  });

  test("nacionalidad solo con showNationality === true", () => {
    assert.equal(
      buildPublicProfile("u1", privateDoc, [], null).nationality,
      null,
    );
    assert.equal(
      buildPublicProfile("u1", {...privateDoc, showNationality: "true"}, [],
        null).nationality,
      null,
    );
    assert.equal(
      buildPublicProfile("u1", {...privateDoc, showNationality: true}, [],
        null).nationality,
      "Salvadoreña",
    );
  });

  test("communityVisible: por defecto true; false o borrado lo ocultan", () => {
    const visible = buildPublicProfile("u1", privateDoc, [], null);
    assert.equal(visible.communityVisible, true);
    assert.equal(buildPublicProfile("u1",
      {...privateDoc, communityVisible: false}, [], null).communityVisible,
    false);
    assert.equal(buildPublicProfile("u1",
      {...privateDoc, communityVisible: true, deletionRequestedAt: ts(T0)},
      [], null).communityVisible, false);
  });

  test("célula: nombre del catálogo, texto libre, 'otra' u oculta", () => {
    assert.equal(resolveCellName(privateDoc, "Célula Norte"), "Célula Norte");
    assert.equal(resolveCellName(privateDoc, null), "celula-1");
    assert.equal(resolveCellName({cellId: "Otra"}, null), null);
    assert.equal(resolveCellName({cellId: "  "}, null), null);
    assert.equal(resolveCellName({}, null), null);
    assert.equal(
      resolveCellName({...privateDoc, showCell: false}, "Célula Norte"),
      null,
    );
    assert.equal(buildPublicProfile("u1", {...privateDoc, showCell: false},
      [], "Célula Norte").cellName, null);
  });
});

describe("buildPublicProfile – contenido", () => {
  test("nombre, iniciales y valores por defecto", () => {
    const profile = buildPublicProfile("u1", privateDoc, [], null);
    assert.equal(profile.displayName, "Ana María Pérez");
    assert.equal(profile.initials, "AM");
    const empty = buildPublicProfile("u2", {}, [], null);
    assert.equal(empty.displayName, "Misionero");
    assert.equal(empty.initials, "CM");
    assert.deepEqual(empty.stampIds, []);
    assert.equal(empty.stampCount, 0);
    assert.equal(initialsFor("ángel"), "Á");
  });

  test("stampIds = unión ordenada de canjes y heredados", () => {
    const profile = buildPublicProfile("u1", privateDoc, ["m3", "m1"], null);
    assert.deepEqual(profile.stampIds, ["m1", "m2", "m3"]);
    assert.equal(profile.stampCount, 3);
  });

  test("máximo 200 stampIds", () => {
    const ids = Array.from({length: 250}, (_, i) => `m${1000 + i}`);
    const profile = buildPublicProfile("u1", {}, ids, null);
    assert.equal(profile.stampIds.length, 200);
    assert.equal(profile.stampCount, 250);
  });

  test("samePublicProfile ignora updatedAt y detecta cambios", () => {
    const profile = buildPublicProfile("u1", privateDoc, ["m3"], null);
    const stored = {...profile, updatedAt: ts(T0)};
    assert.equal(samePublicProfile(profile, stored), true);
    assert.equal(samePublicProfile(profile, undefined), false);
    assert.equal(
      samePublicProfile(profile, {...stored, stampIds: ["m1"]}),
      false,
    );
    assert.equal(
      samePublicProfile(profile, {...stored, displayName: "Otro"}),
      false,
    );
    assert.equal(
      samePublicProfile(profile, {...stored, username: "filtrado"}),
      false,
    );
  });
});
