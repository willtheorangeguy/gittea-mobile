import type {
  ActivityListResponse,
  AddOrganizationResponse,
  AddRepositoryResponse,
  AppConfigResponse,
  DashboardResponse,
  HealthResponse,
  OrganizationListResponse,
  OrganizationMutationResponse,
  OrganizationStatusResponse,
  RateLimitResponse,
  RepositoryListResponse,
  RepositoryMutationResponse,
  RepositoryStatusResponse,
} from "../types/giteaMirror";

type RequestOptions = RequestInit & {
  skipJson?: boolean;
};

export class ApiError extends Error {
  isAuthError: boolean;
  payload: unknown;
  status: number;

  constructor(message: string, status = 0, payload?: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.payload = payload;
    this.isAuthError = status === 401 || status === 403;
  }
}

function extractErrorMessage(payload: unknown, fallback: string) {
  if (!payload || typeof payload !== "object") {
    return fallback;
  }

  const record = payload as Record<string, unknown>;
  return (
    (typeof record.message === "string" && record.message) ||
    (typeof record.error === "string" && record.error) ||
    (typeof record.error_description === "string" && record.error_description) ||
    fallback
  );
}

async function parsePayload(response: Response) {
  const text = await response.text();
  if (!text) {
    return null;
  }

  try {
    return JSON.parse(text) as unknown;
  } catch {
    return text;
  }
}

export function normalizeBaseUrl(value: string) {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new ApiError("Enter your Gitea Mirror URL.");
  }

  const withProtocol = /^https?:\/\//i.test(trimmed)
    ? trimmed
    : `https://${trimmed}`;
  const parsed = new URL(withProtocol);
  const pathname =
    parsed.pathname === "/" ? "" : parsed.pathname.replace(/\/+$/, "");

  return `${parsed.origin}${pathname}`;
}

export class GiteaMirrorClient {
  baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = normalizeBaseUrl(baseUrl);
  }

  private async request<T>(path: string, options: RequestOptions = {}) {
    const headers = new Headers(options.headers);
    if (!headers.has("Content-Type") && options.body) {
      headers.set("Content-Type", "application/json");
    }
    if (!headers.has("Accept")) {
      headers.set("Accept", "application/json");
    }

    let response: Response;
    try {
      response = await fetch(`${this.baseUrl}${path}`, {
        ...options,
        credentials: "include",
        headers,
      });
    } catch (error) {
      throw new ApiError(
        error instanceof Error ? error.message : "Network request failed.",
      );
    }

    const payload = await parsePayload(response);

    if (!response.ok) {
      throw new ApiError(
        extractErrorMessage(payload, `Request failed with ${response.status}`),
        response.status,
        payload,
      );
    }

    if (options.skipJson) {
      return undefined as T;
    }

    return payload as T;
  }

  getHealth() {
    return this.request<HealthResponse>("/api/health");
  }

  getDashboard() {
    return this.request<DashboardResponse>("/api/dashboard");
  }

  getRepositories() {
    return this.request<RepositoryListResponse>("/api/github/repositories");
  }

  getOrganizations() {
    return this.request<OrganizationListResponse>("/api/github/organizations");
  }

  getActivities() {
    return this.request<ActivityListResponse>("/api/activities");
  }

  getConfig() {
    return this.request<AppConfigResponse>("/api/config");
  }

  getRateLimit() {
    return this.request<RateLimitResponse>("/api/rate-limit");
  }

  login(email: string, password: string) {
    return this.request<void>("/api/auth/sign-in/email", {
      body: JSON.stringify({ email, password }),
      method: "POST",
      skipJson: true,
    });
  }

  logout() {
    return this.request<void>("/api/auth/sign-out", {
      method: "POST",
      skipJson: true,
    });
  }

  mirrorRepositories(repositoryIds: string[]) {
    return this.request<RepositoryMutationResponse>("/api/job/mirror-repo", {
      body: JSON.stringify({ repositoryIds }),
      method: "POST",
    });
  }

  syncRepositories(repositoryIds: string[]) {
    return this.request<RepositoryMutationResponse>("/api/job/sync-repo", {
      body: JSON.stringify({ repositoryIds }),
      method: "POST",
    });
  }

  retryRepositories(repositoryIds: string[]) {
    return this.request<RepositoryMutationResponse>("/api/job/retry-repo", {
      body: JSON.stringify({ repositoryIds }),
      method: "POST",
    });
  }

  approveSync(repositoryIds: string[], action: "approve" | "dismiss") {
    return this.request<RepositoryMutationResponse>("/api/job/approve-sync", {
      body: JSON.stringify({ repositoryIds, action }),
      method: "POST",
    });
  }

  updateRepositoryStatus(
    repositoryId: string,
    status: "ignored" | "imported",
  ) {
    return this.request<RepositoryStatusResponse>(
      `/api/repositories/${repositoryId}/status`,
      {
        body: JSON.stringify({ status }),
        method: "PATCH",
      },
    );
  }

  addRepository(owner: string, repo: string) {
    return this.request<AddRepositoryResponse>("/api/sync/repository", {
      body: JSON.stringify({ owner, repo }),
      method: "POST",
    });
  }

  mirrorOrganizations(organizationIds: string[]) {
    return this.request<OrganizationMutationResponse>("/api/job/mirror-org", {
      body: JSON.stringify({ organizationIds }),
      method: "POST",
    });
  }

  updateOrganizationStatus(
    organizationId: string,
    status: "ignored" | "imported",
  ) {
    return this.request<OrganizationStatusResponse>(
      `/api/organizations/${organizationId}/status`,
      {
        body: JSON.stringify({ status }),
        method: "PATCH",
      },
    );
  }

  addOrganization(
    org: string,
    role: "member" | "admin" | "owner" | "billing_manager",
  ) {
    return this.request<AddOrganizationResponse>("/api/sync/organization", {
      body: JSON.stringify({ org, role }),
      method: "POST",
    });
  }
}
