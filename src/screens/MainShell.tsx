import { Ionicons } from "@expo/vector-icons";
import { SafeAreaView, StyleSheet, Text, View, Pressable } from "react-native";
import { useState } from "react";
import { DashboardTab } from "./DashboardTab";
import { OrganizationsTab } from "./OrganizationsTab";
import { RepositoriesTab } from "./RepositoriesTab";
import { SettingsTab } from "./SettingsTab";
import type {
  AppConfigResponse,
  DashboardResponse,
  HealthResponse,
  MembershipRole,
  MirrorJob,
  MirrorOrganization,
  MirrorRepository,
  RateLimitResponse,
} from "../types/giteaMirror";
import { palette, radius } from "../theme";

type TabKey = "dashboard" | "repositories" | "organizations" | "settings";

interface MainShellProps {
  activities: MirrorJob[];
  baseUrl: string;
  busyLabel: string | null;
  busyOrganizationId: string | null;
  busyRepositoryId: string | null;
  config: AppConfigResponse | null;
  dashboard: DashboardResponse | null;
  health: HealthResponse | null;
  onAddOrganization: (input: {
    org: string;
    role: MembershipRole;
  }) => Promise<boolean>;
  onAddRepository: (input: { owner: string; repo: string }) => Promise<boolean>;
  onChangeInstance: () => void;
  onIgnoreOrganization: (organizationId: string) => void;
  onIgnoreRepository: (repositoryId: string) => void;
  onIncludeOrganization: (organizationId: string) => void;
  onIncludeRepository: (repositoryId: string) => void;
  onMirrorOrganization: (organizationId: string) => void;
  onMirrorRepository: (repositoryId: string) => void;
  onRefresh: () => void;
  onRepositoryApproval: (
    repositoryId: string,
    action: "approve" | "dismiss",
  ) => void;
  onRetryRepository: (repositoryId: string) => void;
  onSignOut: () => void;
  onSyncRepository: (repositoryId: string) => void;
  organizations: MirrorOrganization[];
  rateLimit: RateLimitResponse | null;
  refreshing: boolean;
  repositories: MirrorRepository[];
}

const tabs = [
  { key: "dashboard", label: "Dashboard", icon: "speedometer-outline" },
  { key: "repositories", label: "Repos", icon: "git-branch-outline" },
  { key: "organizations", label: "Orgs", icon: "business-outline" },
  { key: "settings", label: "Settings", icon: "options-outline" },
] as const;

export function MainShell(props: MainShellProps) {
  const [activeTab, setActiveTab] = useState<TabKey>("dashboard");

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <Text style={styles.title}>Gitea Mirror Mobile</Text>
        <Text style={styles.subtitle}>
          {props.busyLabel || "Monitoring your mirror from iPhone."}
        </Text>
      </View>

      <View style={styles.content}>
        {activeTab === "dashboard" ? (
          <DashboardTab
            activities={props.activities}
            baseUrl={props.baseUrl}
            config={props.config}
            dashboard={props.dashboard}
            health={props.health}
            onRefresh={props.onRefresh}
            rateLimit={props.rateLimit}
            refreshing={props.refreshing}
          />
        ) : null}

        {activeTab === "repositories" ? (
          <RepositoriesTab
            busyRepositoryId={props.busyRepositoryId}
            config={props.config}
            onAddRepository={props.onAddRepository}
            onApprove={(repositoryId) =>
              props.onRepositoryApproval(repositoryId, "approve")
            }
            onDismiss={(repositoryId) =>
              props.onRepositoryApproval(repositoryId, "dismiss")
            }
            onIgnore={props.onIgnoreRepository}
            onInclude={props.onIncludeRepository}
            onMirror={props.onMirrorRepository}
            onRefresh={props.onRefresh}
            onRetry={props.onRetryRepository}
            onSync={props.onSyncRepository}
            refreshing={props.refreshing}
            repositories={props.repositories}
          />
        ) : null}

        {activeTab === "organizations" ? (
          <OrganizationsTab
            busyOrganizationId={props.busyOrganizationId}
            config={props.config}
            onAddOrganization={props.onAddOrganization}
            onIgnore={props.onIgnoreOrganization}
            onInclude={props.onIncludeOrganization}
            onMirror={props.onMirrorOrganization}
            onRefresh={props.onRefresh}
            organizations={props.organizations}
            refreshing={props.refreshing}
          />
        ) : null}

        {activeTab === "settings" ? (
          <SettingsTab
            baseUrl={props.baseUrl}
            config={props.config}
            health={props.health}
            onChangeInstance={props.onChangeInstance}
            onRefresh={props.onRefresh}
            onSignOut={props.onSignOut}
            refreshing={props.refreshing}
          />
        ) : null}
      </View>

      <View style={styles.tabBar}>
        {tabs.map((tab) => {
          const selected = activeTab === tab.key;

          return (
            <Pressable
              key={tab.key}
              onPress={() => setActiveTab(tab.key)}
              style={[styles.tabButton, selected && styles.tabButtonActive]}
            >
              <Ionicons
                color={selected ? palette.background : palette.textMuted}
                name={tab.icon}
                size={18}
              />
              <Text style={[styles.tabLabel, selected && styles.tabLabelActive]}>
                {tab.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  content: {
    flex: 1,
  },
  header: {
    borderBottomColor: palette.border,
    borderBottomWidth: 1,
    paddingHorizontal: 18,
    paddingTop: 8,
    paddingBottom: 14,
  },
  safeArea: {
    backgroundColor: palette.background,
    flex: 1,
  },
  subtitle: {
    color: palette.textMuted,
    fontSize: 14,
    marginTop: 4,
  },
  tabBar: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: radius.pill,
    borderWidth: 1,
    bottom: 18,
    flexDirection: "row",
    gap: 8,
    left: 18,
    padding: 8,
    position: "absolute",
    right: 18,
  },
  tabButton: {
    alignItems: "center",
    borderRadius: radius.pill,
    flex: 1,
    gap: 6,
    justifyContent: "center",
    minHeight: 54,
  },
  tabButtonActive: {
    backgroundColor: palette.accent,
  },
  tabLabel: {
    color: palette.textMuted,
    fontSize: 11,
    fontWeight: "700",
  },
  tabLabelActive: {
    color: palette.background,
  },
  title: {
    color: palette.text,
    fontSize: 23,
    fontWeight: "900",
  },
});
