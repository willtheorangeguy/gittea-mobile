import {
  formatCount,
  formatDateTime,
  formatRelativeTime,
  formatStatusLabel,
  normalizeDisplayUrl,
} from "../lib/format";

describe("formatStatusLabel", () => {
  it("capitalizes each word and replaces hyphens with spaces", () => {
    expect(formatStatusLabel("pending-sync")).toBe("Pending Sync");
  });

  it("handles a single word", () => {
    expect(formatStatusLabel("imported")).toBe("Imported");
  });

  it("handles an already-formatted string", () => {
    expect(formatStatusLabel("Mirror Complete")).toBe("Mirror Complete");
  });
});

describe("formatRelativeTime", () => {
  const now = Date.now();

  it("returns 'Never' for null", () => {
    expect(formatRelativeTime(null)).toBe("Never");
  });

  it("returns 'Never' for undefined", () => {
    expect(formatRelativeTime(undefined)).toBe("Never");
  });

  it("returns 'Unknown' for an invalid date string", () => {
    expect(formatRelativeTime("not-a-date")).toBe("Unknown");
  });

  it("returns 'Just now' for a timestamp less than 45 seconds ago", () => {
    const ts = new Date(now - 10_000).toISOString();
    expect(formatRelativeTime(ts)).toBe("Just now");
  });

  it("returns minutes ago for timestamps under 60 minutes", () => {
    const ts = new Date(now - 5 * 60_000).toISOString();
    expect(formatRelativeTime(ts)).toBe("5m ago");
  });

  it("returns hours ago for timestamps under 24 hours", () => {
    const ts = new Date(now - 3 * 3_600_000).toISOString();
    expect(formatRelativeTime(ts)).toBe("3h ago");
  });

  it("returns days ago for timestamps under 7 days", () => {
    const ts = new Date(now - 2 * 86_400_000).toISOString();
    expect(formatRelativeTime(ts)).toBe("2d ago");
  });

  it("returns locale date string for timestamps 7 or more days ago", () => {
    const date = new Date(now - 10 * 86_400_000);
    const ts = date.toISOString();
    expect(formatRelativeTime(ts)).toBe(date.toLocaleDateString());
  });
});

describe("formatDateTime", () => {
  it("returns 'Not available' for null", () => {
    expect(formatDateTime(null)).toBe("Not available");
  });

  it("returns 'Not available' for undefined", () => {
    expect(formatDateTime(undefined)).toBe("Not available");
  });

  it("returns 'Not available' for an invalid date string", () => {
    expect(formatDateTime("garbage")).toBe("Not available");
  });

  it("returns locale date string for a valid ISO date", () => {
    const date = new Date("2024-06-15T12:00:00Z");
    expect(formatDateTime("2024-06-15T12:00:00Z")).toBe(date.toLocaleString());
  });
});

describe("formatCount", () => {
  it("formats zero", () => {
    expect(formatCount(0)).toBe("0");
  });

  it("formats a three-digit number without separator", () => {
    expect(formatCount(999)).toBe("999");
  });

  it("formats a number with thousands separator", () => {
    const result = formatCount(1_000);
    expect(result).toMatch(/1.000|1,000/);
  });

  it("formats a large number", () => {
    const result = formatCount(1_234_567);
    expect(result).toMatch(/1.234.567|1,234,567/);
  });
});

describe("normalizeDisplayUrl", () => {
  it("returns host only for root path", () => {
    expect(normalizeDisplayUrl("https://example.com/")).toBe("example.com");
  });

  it("returns host with non-root path", () => {
    expect(normalizeDisplayUrl("https://example.com/gitea")).toBe(
      "example.com/gitea",
    );
  });

  it("returns original string for an invalid URL", () => {
    expect(normalizeDisplayUrl("not-a-url")).toBe("not-a-url");
  });
});
