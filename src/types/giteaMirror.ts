export type RepoStatus =
  | "imported"
  | "mirroring"
  | "mirrored"
  | "failed"
  | "skipped"
  | "ignored"
  | "deleting"
  | "deleted"
  | "syncing"
  | "synced"
  | "archived"
  | "pending-approval";

export type MembershipRole =
  | "member"
  | "admin"
  | "owner"
  | "billing_manager";

export interface MirrorRepository {
  id: string;
  name: string;
  fullName: string;
  owner: string;
  organization?: string | null;
  destinationOrg?: string | null;
  url: string;
  cloneUrl: string;
  mirroredLocation?: string | null;
  isPrivate: boolean;
  isForked: boolean;
  isStarred: boolean;
  isArchived: boolean;
  language?: string | null;
  description?: string | null;
  defaultBranch: string;
  visibility: string;
  status: RepoStatus;
  lastMirrored?: string | null;
  errorMessage?: string | null;
  importedAt?: string | null;
  updatedAt?: string | null;
}

export interface MirrorOrganization {
  id: string;
  name: string;
  avatarUrl?: string | null;
  membershipRole: MembershipRole;
  destinationOrg?: string | null;
  status: RepoStatus;
  repositoryCount: number;
  publicRepositoryCount?: number;
  privateRepositoryCount?: number;
  forkRepositoryCount?: number;
  errorMessage?: string | null;
  lastMirrored?: string | null;
  updatedAt?: string | null;
}

export interface MirrorJob {
  id: string;
  repositoryId?: string | null;
  repositoryName?: string | null;
  organizationId?: string | null;
  organizationName?: string | null;
  status: RepoStatus;
  message: string;
  details?: string | null;
  timestamp: string;
  jobType?: string;
  inProgress?: boolean;
  completedItems?: number;
  totalItems?: number | null;
}

export interface DashboardResponse {
  success: true;
  message: string;
  repoCount: number;
  orgCount: number;
  mirroredCount: number;
  repositories: MirrorRepository[];
  organizations: MirrorOrganization[];
  activities: MirrorJob[];
  lastSync?: string | null;
}

export interface HealthResponse {
  status: "ok" | "error" | "degraded";
  timestamp: string;
  version: string;
  latestVersion: string;
  updateAvailable: boolean;
  database: {
    connected: boolean;
  };
  recovery?: {
    status: string;
    jobsNeedingRecovery: number;
  };
}

export interface RateLimitResponse {
  limit: number;
  remaining: number;
  used: number;
  reset: string;
  retryAfter?: number;
  status: string;
  lastChecked: string;
  percentage?: number;
  minutesUntilReset?: number;
  message?: string;
}

export interface AppConfigResponse {
  id: string;
  userId: string;
  name: string;
  isActive: boolean;
  githubConfig: {
    username?: string;
    token?: string;
    mirrorStarred?: boolean;
    privateRepositories?: boolean;
    starredLists?: string[];
  };
  giteaConfig: {
    url: string;
    externalUrl?: string;
    username?: string;
    organization?: string;
    visibility?: string;
    preserveOrgStructure?: boolean;
    mirrorStrategy?: string;
    personalReposOrg?: string;
  };
  scheduleConfig: {
    enabled: boolean;
    interval: string | number;
    timezone?: string;
    lastRun?: string | null;
    nextRun?: string | null;
  };
  cleanupConfig: {
    enabled: boolean;
    deleteIfNotInGitHub?: boolean;
    orphanedRepoAction?: string;
    dryRun?: boolean;
  };
  mirrorOptions?: {
    mirrorMetadata?: boolean;
    mirrorReleases?: boolean;
    mirrorLFS?: boolean;
  };
  advancedOptions?: {
    skipForks?: boolean;
    starredCodeOnly?: boolean;
    autoMirrorStarred?: boolean;
  };
}

export interface RepositoryListResponse {
  success: boolean;
  message: string;
  repositories: MirrorRepository[];
  error?: string;
}

export interface OrganizationListResponse {
  success: boolean;
  message: string;
  organizations: MirrorOrganization[];
  error?: string;
}

export interface ActivityListResponse {
  success: boolean;
  message: string;
  activities: MirrorJob[];
  error?: string;
}

export interface RepositoryMutationResponse {
  success: boolean;
  message?: string;
  error?: string;
  repositories: MirrorRepository[];
}

export interface OrganizationMutationResponse {
  success: boolean;
  message?: string;
  error?: string;
  organizations: MirrorOrganization[];
}

export interface RepositoryStatusResponse {
  success: boolean;
  repository: MirrorRepository;
  error?: string;
}

export interface OrganizationStatusResponse {
  success: boolean;
  organization: MirrorOrganization;
  error?: string;
}

export interface AddRepositoryResponse {
  success: boolean;
  message: string;
  repository?: MirrorRepository;
  error?: string;
}

export interface AddOrganizationResponse {
  success: boolean;
  message: string;
  organization?: MirrorOrganization;
  error?: string;
}
