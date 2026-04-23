import {
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { ActivityRow } from "../components/ActivityRow";
import {
  AppCard,
  EmptyState,
  MetricCard,
  SectionTitle,
} from "../components/Primitives";
import { formatCount, formatDateTime, formatRelativeTime } from "../lib/format";
import type {
  AppConfigResponse,
  DashboardResponse,
  HealthResponse,
  MirrorJob,
  RateLimitResponse,
} from "../types/giteaMirror";
import { palette } from "../theme";

interface DashboardTabProps {
  activities: MirrorJob[];
  baseUrl: string;
  config: AppConfigResponse | null;
  dashboard: DashboardResponse | null;
  health: HealthResponse | null;
  onRefresh: () => void;
  rateLimit: RateLimitResponse | null;
  refreshing: boolean;
}

export function DashboardTab({
  activities,
  baseUrl,
  config,
  dashboard,
  health,
  onRefresh,
  rateLimit,
  refreshing,
}: DashboardTabProps) {
  return (
    <ScrollView
      contentContainerStyle={styles.content}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={palette.accent} />
      }
    >
      <AppCard style={styles.heroCard}>
        <Text style={styles.heroEyebrow}>Connected</Text>
        <Text style={styles.heroTitle}>{baseUrl}</Text>
        <Text style={styles.heroSubtitle}>
          Health: {health?.status || "unknown"} • Last sync:{" "}
          {formatRelativeTime(dashboard?.lastSync)}
        </Text>
      </AppCard>

      <View style={styles.metricsRow}>
        <MetricCard
          label="Repositories"
          note="Tracked in this account"
          value={formatCount(dashboard?.repoCount || 0)}
        />
        <MetricCard
          label="Organizations"
          note="Imported from GitHub"
          value={formatCount(dashboard?.orgCount || 0)}
        />
        <MetricCard
          label="Healthy Mirrors"
          note="Mirrored or synced"
          value={formatCount(dashboard?.mirroredCount || 0)}
        />
      </View>

      <AppCard>
        <SectionTitle
          subtitle="Quick read on the server and scheduler state."
          title="Instance Summary"
        />
        <View style={styles.summaryGrid}>
          <View style={styles.summaryItem}>
            <Text style={styles.summaryLabel}>Server Version</Text>
            <Text style={styles.summaryValue}>
              {health?.version || "unknown"}
            </Text>
          </View>
          <View style={styles.summaryItem}>
            <Text style={styles.summaryLabel}>Update Available</Text>
            <Text style={styles.summaryValue}>
              {health?.updateAvailable ? "Yes" : "No"}
            </Text>
          </View>
          <View style={styles.summaryItem}>
            <Text style={styles.summaryLabel}>Next Scheduled Run</Text>
            <Text style={styles.summaryValue}>
              {formatDateTime(config?.scheduleConfig.nextRun)}
            </Text>
          </View>
          <View style={styles.summaryItem}>
            <Text style={styles.summaryLabel}>Mirror Strategy</Text>
            <Text style={styles.summaryValue}>
              {config?.giteaConfig.mirrorStrategy || "preserve"}
            </Text>
          </View>
        </View>
      </AppCard>

      {rateLimit ? (
        <AppCard>
          <SectionTitle
            subtitle="GitHub API capacity from the upstream app."
            title="Rate Limit"
          />
          <Text style={styles.rateValue}>
            {formatCount(rateLimit.remaining)} / {formatCount(rateLimit.limit)}
          </Text>
          <Text style={styles.rateMeta}>
            {rateLimit.message || "No rate limit message available."}
          </Text>
        </AppCard>
      ) : null}

      <View style={styles.section}>
        <SectionTitle
          subtitle="Latest mirror activity from the instance."
          title="Recent Activity"
        />
        {activities.length === 0 ? (
          <EmptyState
            subtitle="Once mirroring starts, job events will appear here."
            title="No activity yet"
          />
        ) : (
          <View style={styles.list}>
            {activities.slice(0, 8).map((activity) => (
              <ActivityRow activity={activity} key={activity.id} />
            ))}
          </View>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: {
    gap: 16,
    padding: 18,
    paddingBottom: 120,
  },
  heroCard: {
    backgroundColor: palette.surfaceBright,
  },
  heroEyebrow: {
    color: palette.accent,
    fontSize: 12,
    fontWeight: "800",
    letterSpacing: 1.1,
    textTransform: "uppercase",
  },
  heroSubtitle: {
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 21,
    marginTop: 8,
  },
  heroTitle: {
    color: palette.text,
    fontSize: 24,
    fontWeight: "900",
    marginTop: 8,
  },
  list: {
    gap: 12,
  },
  metricsRow: {
    gap: 12,
  },
  rateMeta: {
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 21,
    marginTop: 10,
  },
  rateValue: {
    color: palette.text,
    fontSize: 28,
    fontWeight: "900",
  },
  section: {
    gap: 14,
  },
  summaryGrid: {
    gap: 14,
  },
  summaryItem: {
    borderTopColor: palette.border,
    borderTopWidth: 1,
    paddingTop: 12,
  },
  summaryLabel: {
    color: palette.textSoft,
    fontSize: 12,
    fontWeight: "700",
    letterSpacing: 0.5,
    textTransform: "uppercase",
  },
  summaryValue: {
    color: palette.text,
    fontSize: 15,
    fontWeight: "700",
    marginTop: 6,
  },
});
