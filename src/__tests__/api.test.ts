import { ApiError, normalizeBaseUrl } from "../lib/api";

describe("ApiError", () => {
  it("sets message and name", () => {
    const error = new ApiError("Something went wrong");
    expect(error.message).toBe("Something went wrong");
    expect(error.name).toBe("ApiError");
  });

  it("defaults status to 0 and isAuthError to false", () => {
    const error = new ApiError("Oops");
    expect(error.status).toBe(0);
    expect(error.isAuthError).toBe(false);
  });

  it("marks 401 responses as auth errors", () => {
    const error = new ApiError("Unauthorized", 401);
    expect(error.isAuthError).toBe(true);
  });

  it("marks 403 responses as auth errors", () => {
    const error = new ApiError("Forbidden", 403);
    expect(error.isAuthError).toBe(true);
  });

  it("does not mark other status codes as auth errors", () => {
    const error = new ApiError("Server error", 500);
    expect(error.isAuthError).toBe(false);
  });

  it("stores an optional payload", () => {
    const payload = { detail: "extra info" };
    const error = new ApiError("Bad request", 400, payload);
    expect(error.payload).toBe(payload);
  });

  it("is an instance of Error", () => {
    expect(new ApiError("err")).toBeInstanceOf(Error);
  });
});

describe("normalizeBaseUrl", () => {
  it("throws ApiError for an empty string", () => {
    expect(() => normalizeBaseUrl("")).toThrow(ApiError);
    expect(() => normalizeBaseUrl("   ")).toThrow(ApiError);
  });

  it("returns trimmed URL as-is when it already has a protocol", () => {
    expect(normalizeBaseUrl("https://example.com")).toBe("https://example.com");
  });

  it("prepends https:// when no protocol is provided", () => {
    expect(normalizeBaseUrl("example.com")).toBe("https://example.com");
  });

  it("strips a trailing slash", () => {
    expect(normalizeBaseUrl("https://example.com/")).toBe(
      "https://example.com",
    );
  });

  it("preserves a sub-path and strips trailing slash", () => {
    expect(normalizeBaseUrl("https://example.com/gitea/")).toBe(
      "https://example.com/gitea",
    );
  });

  it("preserves a sub-path without trailing slash", () => {
    expect(normalizeBaseUrl("https://example.com/gitea")).toBe(
      "https://example.com/gitea",
    );
  });

  it("handles http:// protocol", () => {
    expect(normalizeBaseUrl("http://example.com")).toBe("http://example.com");
  });

  it("trims leading and trailing whitespace", () => {
    expect(normalizeBaseUrl("  https://example.com  ")).toBe(
      "https://example.com",
    );
  });
});
