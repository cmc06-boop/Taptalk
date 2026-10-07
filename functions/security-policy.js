const {createHash, randomBytes} = require('node:crypto');
const hash = value => createHash('sha256').update(value).digest('hex');
const newId = () => randomBytes(32).toString('hex');
function trusted(auth, security) {
  return !!auth && !!security?.sessionId &&
    auth.token?.trustedSession === security.sessionId;
}
function deviceMatches(secret, security) {
  return typeof secret === 'string' && /^[a-f0-9]{64}$/.test(secret) &&
    hash(secret) === security?.deviceHash;
}
function canConfirm(request, uid, secret, security, now) {
  return request?.uid === uid && request.kind === 'replacement' && request.status === 'approved' &&
    request.deviceHash === hash(secret) && request.expiresAt > now &&
    request.generation === (security?.generation ?? 0);
}
module.exports = {hash, newId, trusted, deviceMatches, canConfirm};
