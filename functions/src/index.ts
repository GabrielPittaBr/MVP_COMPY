import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2';

import { administrativeFunctionsRegion } from './config.js';

// Inicializa explicitamente o Admin SDK para que Auth e Firestore estejam
// disponíveis dentro dos handlers gen2.
initializeApp();

setGlobalOptions({ region: administrativeFunctionsRegion });

export { administrativeFunctionsRegion } from './config.js';
export { getAdminUserAuthDetails, getAdminUsersAuthStatus } from './admin_auth_read.js';
export { setUserSuspension } from './user_suspension.js';
export { autoEndOverdueEvents } from './event_lifecycle.js';
export { submitEventRatings } from './event_ratings.js';
export { onEventEnded } from './event_notifications.js';
