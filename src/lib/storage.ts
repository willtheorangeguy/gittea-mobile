import AsyncStorage from "@react-native-async-storage/async-storage";

const INSTANCE_URL_KEY = "gitea-mirror-mobile.instance-url";
const LOGIN_EMAIL_KEY = "gitea-mirror-mobile.login-email";

export async function loadStoredInstanceUrl() {
  return AsyncStorage.getItem(INSTANCE_URL_KEY);
}

export async function saveStoredInstanceUrl(value: string) {
  return AsyncStorage.setItem(INSTANCE_URL_KEY, value);
}

export async function clearStoredInstanceUrl() {
  return AsyncStorage.removeItem(INSTANCE_URL_KEY);
}

export async function loadStoredLoginEmail() {
  return AsyncStorage.getItem(LOGIN_EMAIL_KEY);
}

export async function saveStoredLoginEmail(value: string) {
  return AsyncStorage.setItem(LOGIN_EMAIL_KEY, value);
}
