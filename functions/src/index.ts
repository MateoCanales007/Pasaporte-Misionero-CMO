// Debe ir primero: inicializa Admin SDK y las opciones globales.
import "./setup";

// Callables (contrato en docs/ARQUITECTURA.md §6).
export {issueQrToken} from "./qr/issueQrToken";
export {redeemStamp} from "./qr/redeemStamp";
export {saveMission} from "./missions/saveMission";
export {setMissionStatus} from "./missions/setMissionStatus";
export {setUserRole} from "./roles/setUserRole";
export {fetchVideoMetadata} from "./sermons/fetchVideoMetadata";
export {createRecoveryCode} from "./recovery/createRecoveryCode";
export {redeemRecoveryCode} from "./recovery/redeemRecoveryCode";
export {requestAccountDeletion} from "./account/requestAccountDeletion";
export {searchPlaces} from "./places/searchPlaces";
export {getPlaceDetails} from "./places/getPlaceDetails";
export {getPhotoReferences} from "./places/getPhotoReferences";
export {getMissionPlacePhoto} from "./places/getMissionPlacePhoto";

// Triggers y tareas.
export {onUserPassportWritten} from "./profiles/onUserPassportWritten";
export {onFcmTokenWritten} from "./notifications/onFcmTokenWritten";
export {onMissionWritten} from "./notifications/onMissionWritten";
export {onSermonWritten} from "./notifications/onSermonWritten";
export {sendMissionReminders} from "./notifications/sendMissionReminders";
export {runMigrations} from "./migrations/runMigrations";
