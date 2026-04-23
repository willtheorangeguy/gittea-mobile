import { Linking, StyleSheet, Text, View } from "react-native";
import type { AppConfigResponse, MirrorRepository } from "../types/giteaMirror";
import { AppButton, AppCard } from "./Primitives";
import { StatusBadge } from "./StatusBadge";
import { formatRelativeTime } from "../lib/format";
import { palette } from "../theme";

interface RepositoryRowProps {
  busy: boolean;
  config: AppConfigResponse | null;
  onApprove: (repositoryId: string) => void;
  onDismiss: (repositoryId: string) => void;
  onIgnore: (repositoryId: string) => void;
  onInclude: (repositoryId: string) => void;
  onMirror: (repositoryId: string) => void;
  onRetry: (repositoryId: string) => void;
  onSync: (repositoryId: string) => void;
  repository: MirrorRepository;
}

export function RepositoryRow({
  busy,
  config,
  onApprove,
  onDismiss,
  onIgnore,
  onInclude,
  onMirror,
  onRetry,
  onSync,
  repository,
}: RepositoryRowProps) {
  const giteaUrl = buildGiteaRepoUrl(config, repository);

  return (
    <AppCard style={styles.card}>
      <View style={styles.header}>
        <View style={styles.identity}>
          <Text style={styles.name}>{repository.name}</Text>
          <Text style={styles.fullName}>{repository.fullName}</Text>
        </View>
        <StatusBadge status={repository.status} />
      </View>

      {repository.description ? (
        <Text style={styles.description}>{repository.description}</Text>
      ) : null}

      <View style={styles.metaRow}>
        <Text style={styles.metaText}>Owner: {repository.owner}</Text>
        <Text style={styles.metaText}>
          Last sync: {formatRelativeTime(repository.lastMirrored)}
        </Text>
      </View>

      {repository.organization ? (
        <Text style={styles.metaSecondary}>GitHub org: {repository.organization}</Text>
      ) : null}

      {repository.destinationOrg ? (
        <Text style={styles.metaSecondary}>Gitea target: {repository.destinationOrg}</Text>
      ) : null}

      {repository.errorMessage ? (
        <Text style={styles.errorText}>{repository.errorMessage}</Text>
      ) : null}

      <View style={styles.actions}>
        {repository.status === "failed" ? (
          <AppButton
            compact
            disabled={busy}
            label="Retry"
            onPress={() => onRetry(repository.id)}
          />
        ) : null}

        {["imported", "mirroring"].includes(repository.status) ? (
          <AppButton
            compact
            disabled={busy || repository.status === "mirroring"}
            label={repository.status === "mirroring" ? "Mirroring" : "Mirror"}
            onPress={() => onMirror(repository.id)}
          />
        ) : null}

        {["mirrored", "synced", "archived", "syncing"].includes(repository.status) ? (
          <AppButton
            compact
            disabled={busy || repository.status === "syncing"}
            label={repository.status === "syncing" ? "Syncing" : "Sync"}
            onPress={() => onSync(repository.id)}
            variant="secondary"
          />
        ) : null}

        {repository.status === "pending-approval" ? (
          <>
            <AppButton
              compact
              disabled={busy}
              label="Approve"
              onPress={() => onApprove(repository.id)}
            />
            <AppButton
              compact
              disabled={busy}
              label="Dismiss"
              onPress={() => onDismiss(repository.id)}
              variant="secondary"
            />
          </>
        ) : null}

        {repository.status === "ignored" ? (
          <AppButton
            compact
            disabled={busy}
            label="Include"
            onPress={() => onInclude(repository.id)}
            variant="secondary"
          />
        ) : null}

        {repository.status !== "ignored" &&
        repository.status !== "pending-approval" ? (
          <AppButton
            compact
            disabled={busy}
            label="Ignore"
            onPress={() => onIgnore(repository.id)}
            variant="ghost"
          />
        ) : null}

        <AppButton
          compact
          disabled={busy}
          label="GitHub"
          onPress={() => void Linking.openURL(repository.url)}
          variant="ghost"
        />

        {giteaUrl ? (
          <AppButton
            compact
            disabled={busy}
            label="Gitea"
            onPress={() => void Linking.openURL(giteaUrl)}
            variant="ghost"
          />
        ) : null}
      </View>
    </AppCard>
  );
}

function buildGiteaRepoUrl(
  config: AppConfigResponse | null,
  repository: MirrorRepository,
) {
  if (!config) {
    return null;
  }

  const baseUrl = config.giteaConfig.externalUrl || config.giteaConfig.url;
  if (!baseUrl) {
    return null;
  }

  if (
    !["mirrored", "mirroring", "synced", "syncing", "archived"].includes(
      repository.status,
    )
  ) {
    return null;
  }

  const repoPath =
    repository.mirroredLocation ||
    `${repository.destinationOrg || repository.organization || repository.owner}/${repository.name}`;

  return `${baseUrl.replace(/\/+$/, "")}/${repoPath.replace(/^\/+/, "")}`;
}

const styles = StyleSheet.create({
  actions: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
    marginTop: 16,
  },
  card: {
    gap: 10,
  },
  description: {
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },
  errorText: {
    color: palette.danger,
    fontSize: 13,
    lineHeight: 19,
  },
  fullName: {
    color: palette.textSoft,
    fontSize: 13,
    marginTop: 4,
  },
  header: {
    alignItems: "flex-start",
    flexDirection: "row",
    gap: 10,
    justifyContent: "space-between",
  },
  identity: {
    flex: 1,
  },
  metaRow: {
    flexDirection: "row",
    gap: 10,
    justifyContent: "space-between",
  },
  metaSecondary: {
    color: palette.textSoft,
    fontSize: 13,
  },
  metaText: {
    color: palette.textMuted,
    flex: 1,
    fontSize: 13,
  },
  name: {
    color: palette.text,
    fontSize: 18,
    fontWeight: "800",
  },
});
