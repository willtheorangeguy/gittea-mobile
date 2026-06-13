import AsyncStorage from "@react-native-async-storage/async-storage";
import {
  clearStoredInstanceUrl,
  loadStoredInstanceUrl,
  loadStoredLoginEmail,
  saveStoredInstanceUrl,
  saveStoredLoginEmail,
} from "../lib/storage";

jest.mock("@react-native-async-storage/async-storage", () => ({
  __esModule: true,
  default: {
    getItem: jest.fn(),
    setItem: jest.fn(),
    removeItem: jest.fn(),
    clear: jest.fn(),
  },
}));

const INSTANCE_KEY = "gitea-mirror-mobile.instance-url";
const EMAIL_KEY = "gitea-mirror-mobile.login-email";

beforeEach(() => {
  (AsyncStorage.clear as jest.Mock).mockClear();
  (AsyncStorage.getItem as jest.Mock).mockClear();
  (AsyncStorage.setItem as jest.Mock).mockClear();
  (AsyncStorage.removeItem as jest.Mock).mockClear();
});

describe("loadStoredInstanceUrl", () => {
  it("returns null when no value is stored", async () => {
    (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce(null);
    const result = await loadStoredInstanceUrl();
    expect(result).toBeNull();
    expect(AsyncStorage.getItem).toHaveBeenCalledWith(INSTANCE_KEY);
  });

  it("returns the stored URL", async () => {
    (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce(
      "https://example.com",
    );
    const result = await loadStoredInstanceUrl();
    expect(result).toBe("https://example.com");
  });
});

describe("saveStoredInstanceUrl", () => {
  it("persists the URL under the expected key", async () => {
    (AsyncStorage.setItem as jest.Mock).mockResolvedValueOnce(undefined);
    await saveStoredInstanceUrl("https://example.com");
    expect(AsyncStorage.setItem).toHaveBeenCalledWith(
      INSTANCE_KEY,
      "https://example.com",
    );
  });
});

describe("clearStoredInstanceUrl", () => {
  it("removes the instance URL key", async () => {
    (AsyncStorage.removeItem as jest.Mock).mockResolvedValueOnce(undefined);
    await clearStoredInstanceUrl();
    expect(AsyncStorage.removeItem).toHaveBeenCalledWith(INSTANCE_KEY);
  });
});

describe("loadStoredLoginEmail", () => {
  it("returns null when no email is stored", async () => {
    (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce(null);
    const result = await loadStoredLoginEmail();
    expect(result).toBeNull();
    expect(AsyncStorage.getItem).toHaveBeenCalledWith(EMAIL_KEY);
  });

  it("returns the stored email", async () => {
    (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce(
      "user@example.com",
    );
    const result = await loadStoredLoginEmail();
    expect(result).toBe("user@example.com");
  });
});

describe("saveStoredLoginEmail", () => {
  it("persists the email under the expected key", async () => {
    (AsyncStorage.setItem as jest.Mock).mockResolvedValueOnce(undefined);
    await saveStoredLoginEmail("user@example.com");
    expect(AsyncStorage.setItem).toHaveBeenCalledWith(
      EMAIL_KEY,
      "user@example.com",
    );
  });
});
