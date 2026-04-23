import { StatusBar } from "expo-status-bar";
import { Alert, StyleSheet, View } from "react-native";
import { useEffect, useState } from "react";
import {
  GiteaMirrorClient,
  ApiError,
  normalizeBaseUrl,
} from "./src/lib/api";
import {
  clearStoredInstanceUrl,
  loadStoredInstanceUrl,
  loadStoredLoginEmail,
  saveStoredInstanceUrl,
  saveStoredLoginEmail,
} from "./src/lib/storage";
import type {
  AppConfigResponse,
  DashboardResponse,
  HealthResponse,
  MirrorJob,
  MirrorOrganization,
  MirrorRepository,
  RateLimitResponse,
} from "./src/types/giteaMirror";
import { ConnectScreen } from "./src/screens/ConnectScreen";
import { LoginScreen } from "./src/screens/LoginScreen";
import { MainShell } from "./src/screens/MainShell";
import { palette } from "./src/theme";

type AppView = "boot" | "connect" | "login" | "ready";

interface AppSnapshot {
  activities: MirrorJob[];
  config: AppConfigResponse | null;
  dashboard: DashboardResponse | null;
  health: HealthResponse | null;
  organizations: MirrorOrganization[];
  rateLimit: RateLimitResponse | null;
  repositories: MirrorRepository[];
}

const emptySnapshot: AppSnapshot = {
  activities: [],
  config: null,
  dashboard: null,
  health: null,
  organizations: [],
  rateLimit: null,
  repositories: [],
};

function getErrorMessage(error: unknown) {
  if (error instanceof ApiError) {
    return error.message;
  }

  if (error instanceof Error) {
    return error.message;
  }

  return "An unexpected error occurred.";
}

function mergeRepositories(
  current: MirrorRepository[],
  updated: MirrorRepository[],
) {
  const lookup = new Map(updated.map((item) => [item.id, item]));
  return current.map((item) => lookup.get(item.id) ?? item);
}

function mergeOrganizations(
  current: MirrorOrganization[],
  updated: MirrorOrganization[],
) {
  const lookup = new Map(updated.map((item) => [item.id, item]));
  return current.map((item) => lookup.get(item.id) ?? item);
}

export default function App() {
  const [view, setView] = useState<AppView>("boot");
  const [instanceUrl, setInstanceUrl] = useState("");
  const [instanceDraft, setInstanceDraft] = useState("");
  const [savedEmail, setSavedEmail] = useState("");
  const [authError, setAuthError] = useState<string | null>(null);
  const [busyLabel, setBusyLabel] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [busyRepositoryId, setBusyRepositoryId] = useState<string | null>(null);
  const [busyOrganizationId, setBusyOrganizationId] = useState<string | null>(
    null,
  );
  const [snapshot, setSnapshot] = useState<AppSnapshot>(emptySnapshot);

  useEffect(() => {
    void bootstrap();
  }, []);

  useEffect(() => {
    if (view !== "ready" || !instanceUrl) {
      return;
    }

    const timer = setInterval(() => {
      void refreshAll(true);
    }, 20000);

    return () => clearInterval(timer);
  }, [instanceUrl, view]);

  async function fetchSnapshot(targetUrl: string) {
    const client = new GiteaMirrorClient(targetUrl);
    const [health, dashboard, repositories, organizations, activities, config, rateLimit] =
      await Promise.all([
        client.getHealth(),
        client.getDashboard(),
        client.getRepositories(),
        client.getOrganizations(),
        client.getActivities(),
        client.getConfig(),
        client.getRateLimit(),
      ]);

    return {
      activities: activities.activities,
      config,
      dashboard,
      health,
      organizations: organizations.organizations,
      rateLimit,
      repositories: repositories.repositories,
    } satisfies AppSnapshot;
  }

  async function bootstrap() {
    setView("boot");

    const [storedUrl, storedEmail] = await Promise.all([
      loadStoredInstanceUrl(),
      loadStoredLoginEmail(),
    ]);

    if (storedEmail) {
      setSavedEmail(storedEmail);
    }

    if (!storedUrl) {
      setView("connect");
      return;
    }

    setInstanceDraft(storedUrl);
    setInstanceUrl(storedUrl);

    try {
      const client = new GiteaMirrorClient(storedUrl);
      const health = await client.getHealth();
      setSnapshot((current) => ({ ...current, health }));

      const nextSnapshot = await fetchSnapshot(storedUrl);
      setSnapshot(nextSnapshot);
      setAuthError(null);
      setView("ready");
    } catch (error) {
      if (error instanceof ApiError && error.isAuthError) {
        setAuthError(null);
        setView("login");
        return;
      }

      setAuthError(getErrorMessage(error));
      setView("connect");
    }
  }

  async function refreshAll(silent = false) {
    if (!instanceUrl) {
      return false;
    }

    if (!silent) {
      setRefreshing(true);
    }

    try {
      const nextSnapshot = await fetchSnapshot(instanceUrl);
      setSnapshot(nextSnapshot);
      setAuthError(null);
      return true;
    } catch (error) {
      if (error instanceof ApiError && error.isAuthError) {
        setAuthError("Your session expired. Sign in again.");
        setView("login");
        return false;
      }

      if (!silent) {
        Alert.alert("Refresh failed", getErrorMessage(error));
      }

      return false;
    } finally {
      if (!silent) {
        setRefreshing(false);
      }
    }
  }

  async function handleConnect() {
    try {
      setBusyLabel("Checking instance");
      setAuthError(null);

      const normalized = normalizeBaseUrl(instanceDraft);
      const client = new GiteaMirrorClient(normalized);
      const health = await client.getHealth();

      await saveStoredInstanceUrl(normalized);
      setInstanceUrl(normalized);
      setInstanceDraft(normalized);
      setSnapshot((current) => ({ ...current, health }));

      try {
        const nextSnapshot = await fetchSnapshot(normalized);
        setSnapshot(nextSnapshot);
        setView("ready");
      } catch (error) {
        if (error instanceof ApiError && error.isAuthError) {
          setView("login");
          return;
        }

        setAuthError(getErrorMessage(error));
        setView("connect");
      }
    } catch (error) {
      setAuthError(
        `${getErrorMessage(error)} If your instance uses a self-signed certificate, Expo Go on iPhone will reject it.`,
      );
    } finally {
      setBusyLabel(null);
    }
  }

  async function handleLogin(email: string, password: string) {
    const targetUrl = instanceUrl || instanceDraft;
    if (!targetUrl) {
      setAuthError("Enter your Gitea Mirror instance URL first.");
      setView("connect");
      return;
    }

    try {
      setBusyLabel("Signing in");
      setAuthError(null);

      const client = new GiteaMirrorClient(targetUrl);
      await client.login(email, password);
      await saveStoredLoginEmail(email);
      setSavedEmail(email);

      const nextSnapshot = await fetchSnapshot(targetUrl);
      setSnapshot(nextSnapshot);
      setInstanceUrl(targetUrl);
      setView("ready");
    } catch (error) {
      setAuthError(getErrorMessage(error));
      setView("login");
    } finally {
      setBusyLabel(null);
    }
  }

  async function handleSignOut() {
    if (!instanceUrl) {
      return;
    }

    try {
      setBusyLabel("Signing out");
      const client = new GiteaMirrorClient(instanceUrl);
      await client.logout();
    } catch {
      // Clearing local app state is still useful even if the cookie clear fails.
    } finally {
      setBusyLabel(null);
      setSnapshot((current) => ({ ...emptySnapshot, health: current.health }));
      setAuthError(null);
      setView("login");
    }
  }

  async function handleChangeInstance() {
    await clearStoredInstanceUrl();
    setInstanceUrl("");
    setInstanceDraft("");
    setSnapshot(emptySnapshot);
    setAuthError(null);
    setView("connect");
  }

  async function handleMirrorRepository(repositoryId: string) {
    if (!instanceUrl) {
      return;
    }

    try {
      setBusyRepositoryId(repositoryId);
      const client = new GiteaMirrorClient(instanceUrl);
      const response = await client.mirrorRepositories([repositoryId]);

      setSnapshot((current) => ({
        ...current,
        repositories: mergeRepositories(current.repositories, response.repositories),
      }));
    } catch (error) {
      Alert.alert("Mirror failed", getErrorMessage(error));
    } finally {
      setBusyRepositoryId(null);
      void refreshAll(true);
    }
  }

  async function handleSyncRepository(repositoryId: string) {
    if (!instanceUrl) {
      return;
    }

    try {
      setBusyRepositoryId(repositoryId);
      const client = new GiteaMirrorClient(instanceUrl);
      const response = await client.syncRepositories([repositoryId]);

      setSnapshot((current) => ({
        ...current,
        repositories: mergeRepositories(current.repositories, response.repositories),
      }));
    } catch (error) {
      Alert.alert("Sync failed", getErrorMessage(error));
    } finally {
      setBusyRepositoryId(null);
      void refreshAll(true);
    }
  }

  async function handleRetryRepository(repositoryId: string) {
    if (!instanceUrl) {
      return;
    }

    try {
      setBusyRepositoryId(repositoryId);
      const client = new GiteaMirrorClient(instanceUrl);
      const response = await client.retryRepositories([repositoryId]);

      setSnapshot((current) => ({
        ...current,
        repositories: mergeRepositories(current.repositories, response.repositories),
      }));
    } catch (error) {
      Alert.alert("Retry failed", getErrorMessage(error));
    } finally {
      setBusyRepositoryId(null);
      void refreshAll(true);
    }
  }

  async function handleRepositoryApproval(
    repositoryId: string,
    action: "approve" | "dismiss",
  ) {
    if (!instanceUrl) {
      return;
    }

    try {
      setBusyRepositoryId(repositoryId);
      const client = new GiteaMirrorClient(instanceUrl);
      const response = await client.approveSync([repositoryId], action);

      setSnapshot((current) => ({
        ...current,
        repositories: mergeRepositories(current.repositories, response.repositories),
      }));
    } catch (error) {
      Alert.alert(
        action === "approve" ? "Approval failed" : "Dismiss failed",
        getErrorMessage(error),
      );
    } finally {
      setBusyRepositoryId(null);
      void refreshAll(true);
    }
  }

  async function handleRepositoryStatus(
    repositoryId: string,
    status: "ignored" | "imported",
  ) {
    if (!instanceUrl) {
      return;
    }

    try {
      setBusyRepositoryId(repositoryId);
      const client = new GiteaMirrorClient(instanceUrl);
      const response = await client.updateRepositoryStatus(repositoryId, status);

      setSnapshot((current) => ({
        ...current,
        repositories: (() => {
          const nextRepositories: MirrorRepository[] = [...current.repositories];
          const targetIndex = nextRepositories.findIndex(
            (item) => item.id === repositoryId,
          );
          const updatedRepository = response.repository;

          if (targetIndex >= 0 && updatedRepository) {
            nextRepositories[targetIndex] = updatedRepository;
          }

          return nextRepositories;
        })(),
      }));
    } catch (error) {
      Alert.alert("Update failed", getErrorMessage(error));
    } finally {
      setBusyRepositoryId(null);
      void refreshAll(true);
    }
  }

  async function handleAddRepository(input: {
    owner: string;
    repo: string;
  }) {
    if (!instanceUrl) {
      return false;
    }

    try {
      setBusyLabel("Adding repository");
      const client = new GiteaMirrorClient(instanceUrl);
      const response = await client.addRepository(input.owner, input.repo);
      const addedRepository = response.repository;

      if (addedRepository) {
        setSnapshot((current) => ({
          ...current,
          repositories: [addedRepository, ...current.repositories],
        }));
      }

      void refreshAll(true);
      return true;
    } catch (error) {
      Alert.alert("Add repository failed", getErrorMessage(error));
      return false;
    } finally {
      setBusyLabel(null);
    }
  }

  async function handleMirrorOrganization(organizationId: string) {
    if (!instanceUrl) {
      return;
    }

    try {
      setBusyOrganizationId(organizationId);
      const client = new GiteaMirrorClient(instanceUrl);
      const response = await client.mirrorOrganizations([organizationId]);

      setSnapshot((current) => ({
        ...current,
        organizations: mergeOrganizations(
          current.organizations,
          response.organizations,
        ),
      }));
    } catch (error) {
      Alert.alert("Mirror failed", getErrorMessage(error));
    } finally {
      setBusyOrganizationId(null);
      void refreshAll(true);
    }
  }

  async function handleOrganizationStatus(
    organizationId: string,
    status: "ignored" | "imported",
  ) {
    if (!instanceUrl) {
      return;
    }

    try {
      setBusyOrganizationId(organizationId);
      const client = new GiteaMirrorClient(instanceUrl);
      const response = await client.updateOrganizationStatus(
        organizationId,
        status,
      );

      setSnapshot((current) => ({
        ...current,
        organizations: (() => {
          const nextOrganizations: MirrorOrganization[] = [
            ...current.organizations,
          ];
          const targetIndex = nextOrganizations.findIndex(
            (item) => item.id === organizationId,
          );
          const updatedOrganization = response.organization;

          if (targetIndex >= 0 && updatedOrganization) {
            nextOrganizations[targetIndex] = updatedOrganization;
          }

          return nextOrganizations;
        })(),
      }));
    } catch (error) {
      Alert.alert("Update failed", getErrorMessage(error));
    } finally {
      setBusyOrganizationId(null);
      void refreshAll(true);
    }
  }

  async function handleAddOrganization(input: {
    org: string;
    role: "member" | "admin" | "owner" | "billing_manager";
  }) {
    if (!instanceUrl) {
      return false;
    }

    try {
      setBusyLabel("Adding organization");
      const client = new GiteaMirrorClient(instanceUrl);
      const response = await client.addOrganization(input.org, input.role);
      const addedOrganization = response.organization;

      if (addedOrganization) {
        setSnapshot((current) => ({
          ...current,
          organizations: [addedOrganization, ...current.organizations],
        }));
      }

      await refreshAll(true);
      return true;
    } catch (error) {
      Alert.alert("Add organization failed", getErrorMessage(error));
      return false;
    } finally {
      setBusyLabel(null);
    }
  }

  return (
    <View style={styles.root}>
      <StatusBar style="light" />

      {view === "boot" ? (
        <View style={styles.loading}>
          <View style={styles.loadingDot} />
        </View>
      ) : null}

      {view === "connect" && (
        <ConnectScreen
          busyLabel={busyLabel}
          errorMessage={authError}
          instanceUrl={instanceDraft}
          onConnect={handleConnect}
          onInstanceUrlChange={setInstanceDraft}
        />
      )}

      {view === "login" && (
        <LoginScreen
          busyLabel={busyLabel}
          errorMessage={authError}
          instanceUrl={instanceUrl || instanceDraft}
          onBack={() => setView("connect")}
          onLogin={handleLogin}
          savedEmail={savedEmail}
        />
      )}

      {view === "ready" && (
        <MainShell
          activities={snapshot.activities}
          baseUrl={instanceUrl}
          busyLabel={busyLabel}
          busyOrganizationId={busyOrganizationId}
          busyRepositoryId={busyRepositoryId}
          config={snapshot.config}
          dashboard={snapshot.dashboard}
          health={snapshot.health}
          onAddOrganization={handleAddOrganization}
          onAddRepository={handleAddRepository}
          onChangeInstance={handleChangeInstance}
          onIgnoreOrganization={(organizationId) =>
            handleOrganizationStatus(organizationId, "ignored")
          }
          onIgnoreRepository={(repositoryId) =>
            handleRepositoryStatus(repositoryId, "ignored")
          }
          onIncludeOrganization={(organizationId) =>
            handleOrganizationStatus(organizationId, "imported")
          }
          onIncludeRepository={(repositoryId) =>
            handleRepositoryStatus(repositoryId, "imported")
          }
          onMirrorOrganization={handleMirrorOrganization}
          onMirrorRepository={handleMirrorRepository}
          onRefresh={() => refreshAll(false)}
          onRepositoryApproval={handleRepositoryApproval}
          onRetryRepository={handleRetryRepository}
          onSignOut={handleSignOut}
          onSyncRepository={handleSyncRepository}
          organizations={snapshot.organizations}
          rateLimit={snapshot.rateLimit}
          refreshing={refreshing}
          repositories={snapshot.repositories}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  loading: {
    alignItems: "center",
    flex: 1,
    justifyContent: "center",
  },
  loadingDot: {
    backgroundColor: palette.accent,
    borderRadius: 999,
    height: 14,
    width: 14,
  },
  root: {
    backgroundColor: palette.background,
    flex: 1,
  },
});
