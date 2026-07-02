import { startAuthentication, startRegistration } from "@simplewebauthn/browser";
import { apiFetch, setTokens } from "./api";

type TokenPair = { access: string; refresh: string; user: unknown };

/** Enrol a new biometric/passkey credential for the currently logged-in user. */
export async function registerBiometricCredential(deviceName: string) {
  const options = await apiFetch<Record<string, unknown>>(
    "/api/auth/webauthn/register/options/",
    { method: "POST" },
  );
  const credential = await startRegistration({ optionsJSON: options as never });

  return apiFetch("/api/auth/webauthn/register/verify/", {
    method: "POST",
    body: JSON.stringify({ credential, device_name: deviceName }),
  });
}

/** Passwordless login using a previously registered biometric/passkey credential. */
export async function loginWithBiometrics(phoneNumber: string) {
  const options = await apiFetch<Record<string, unknown>>(
    "/api/auth/webauthn/authenticate/options/",
    { method: "POST", body: JSON.stringify({ phone_number: phoneNumber }) },
  );
  const credential = await startAuthentication({ optionsJSON: options as never });

  const result = await apiFetch<TokenPair>(
    "/api/auth/webauthn/authenticate/verify/",
    {
      method: "POST",
      body: JSON.stringify({ phone_number: phoneNumber, credential }),
    },
  );
  setTokens(result.access, result.refresh);
  return result;
}
