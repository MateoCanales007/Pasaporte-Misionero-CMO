import {requireRole} from "../core/auth";
import {secureCallable} from "../core/callable";
import {ValidationError} from "../core/errors";
import {requireData} from "../core/validation";
import {resolveVideoMetadata} from "./videoMetadata";

export const fetchVideoMetadata = secureCallable(async (request) => {
  requireRole(request, ["admin"]);
  const data = requireData(request.data);
  if (typeof data.url !== "string") {
    throw new ValidationError("La URL no es válida.", "url");
  }
  return resolveVideoMetadata(data.url);
});
