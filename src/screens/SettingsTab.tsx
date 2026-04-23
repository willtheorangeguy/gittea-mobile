import {
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { AppButton, AppCard, SectionTitle } from "../components/Primitives";
import { formatDateTime, normalizeDisplayUrl } from "../lib/format";
import type { AppConfigResponse, HealthResponse } from "../types/giteaMirror";
import { palette } from "../theme";

interface SettingsTabProps {
  baseUrl: string;
  config: AppConfigResponse | null;
  health: HealthResponse | null;
  onChangeInstance: () => void;
  onRefresh: () => void;
  onSignOut: () => void;
  refreshing: boolean;
}

export function SettingsTab({
  baseUrl,
  config,
  health,
  onChangeInstance,
  onRefresh,
  onSignOut,
  refreshing,
}: SettingsTabProps) {
  return (
    <ScrollView
      contentContainerStyle={styles.content}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={palette.accent} />
      }
    >
      <AppCard>
        <SectionTitle
          subtitle="The mobile client keeps only the instance URL locally."
          title="Connection"
        />
        <Detail label="Instance" value={normalizeDisplayUrl(baseUrl)} />
        <Detail label="Health" value={health?.status || "unknown"} />
        <Detail label="Server Version" value={health?.version || "unknown"} />
      </AppCard>

      {config ? (
        <AppCard>
          <SectionTitle
            subtitle="Read-only summary from your current Gitea Mirror configuration."
            title="Mirror Settings"
          />
          <Detail
            label="GitHub Owner"
            value={config.githubConfig.username || "Not configured"}
          />
          <Detail label="Gitea URL" value={normalizeDisplayUrl(config.giteaConfig.url)} />
          <Detail
            label="Mirror Strategy"
            value={config.giteaConfig.mirrorStrategy || "preserve"}
          />
          <Detail
            label="Schedule"
            value={
              config.scheduleConfig.enabled
                ? String(config.scheduleConfig.interval)
                : "Disabled"
            }
          />
          <Detail
            label="Next Run"
            value={formatDateTime(config.scheduleConfig.nextRun)}
          />
          <Detail
            label="Cleanup Mode"
            value={config.cleanupConfig.orphanedRepoAction || "archive"}
          />
        </AppCard>
      ) : null}

      <AppCard>
        <SectionTitle
          subtitle="Useful controls when switching servers or expiring sessions."
          title="Session"
        />
        <View style={styles.actions}>
          <AppButton label="Refresh Data" onPress={onRefresh} variant="secondary" />
          <AppButton label="Sign Out" onPress={onSignOut} variant="secondary" />
          <AppButton label="Change Instance" onPress={onChangeInstance} variant="danger" />
        </View>
      </AppCard>
    </ScrollView>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detail}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={styles.detailValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  actions: {
    gap: 10,
  },
  content: {
    gap: 16,
    padding: 18,
    paddingBottom: 120,
  },
  detail: {
    borderTopColor: palette.border,
    borderTopWidth: 1,
    paddingTop: 12,
  },
  detailLabel: {
    color: palette.textSoft,
    fontSize: 12,
    fontWeight: "700",
    letterSpacing: 0.5,
    textTransform: "uppercase",
  },
  detailValue: {
    color: palette.text,
    fontSize: 15,
    fontWeight: "700",
    marginTop: 6,
  },
});
