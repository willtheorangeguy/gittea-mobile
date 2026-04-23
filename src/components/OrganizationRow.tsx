import { Linking, StyleSheet, Text, View } from "react-native";
import type { AppConfigResponse, MirrorOrganization } from "../types/giteaMirror";
import { AppButton, AppCard } from "./Primitives";
import { StatusBadge } from "./StatusBadge";
import { palette } from "../theme";

interface OrganizationRowProps {
  busy: boolean;
  config: AppConfigResponse | null;
  onIgnore: (organizationId: string) => void;
  onInclude: (organizationId: string) => void;
  onMirror: (organizationId: string) => void;
  organization: MirrorOrganization;
}

export function OrganizationRow({
  busy,
  config,
  onIgnore,
  onInclude,
  onMirror,
  organization,
}: OrganizationRowProps) {
  const giteaUrl = buildGiteaOrgUrl(config, organization);

  return (
    <AppCard style={styles.card}>
      <View style={styles.header}>
        <View style={styles.identity}>
          <Text style={styles.name}>{organization.name}</Text>
          <Text style={styles.role}>{organization.membershipRole}</Text>
        </View>
        <StatusBadge status={organization.status} />
      </View>

      <View style={styles.stats}>
        <Text style={styles.countText}>{organization.repositoryCount} repositories</Text>
        {organization.publicRepositoryCount ? (
          <Text style={styles.countMeta}>
            {organization.publicRepositoryCount} public
          </Text>
        ) : null}
        {organization.privateRepositoryCount ? (
          <Text style={styles.countMeta}>
            {organization.privateRepositoryCount} private
          </Text>
        ) : null}
      </View>

      {organization.destinationOrg ? (
        <Text style={styles.metaText}>Gitea target: {organization.destinationOrg}</Text>
      ) : null}

      {organization.errorMessage ? (
        <Text style={styles.errorText}>{organization.errorMessage}</Text>
      ) : null}

      <View style={styles.actions}>
        {organization.status === "ignored" ? (
          <AppButton
            compact
            disabled={busy}
            label="Include"
            onPress={() => onInclude(organization.id)}
            variant="secondary"
          />
        ) : (
          <>
            <AppButton
              compact
              disabled={busy || organization.status === "mirroring"}
              label={organization.status === "mirroring" ? "Mirroring" : "Mirror"}
              onPress={() => onMirror(organization.id)}
            />
            <AppButton
              compact
              disabled={busy}
              label="Ignore"
              onPress={() => onIgnore(organization.id)}
              variant="ghost"
            />
          </>
        )}

        <AppButton
          compact
          disabled={busy}
          label="GitHub"
          onPress={() => void Linking.openURL(`https://github.com/${organization.name}`)}
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

function buildGiteaOrgUrl(
  config: AppConfigResponse | null,
  organization: MirrorOrganization,
) {
  if (!config) {
    return null;
  }

  const baseUrl = config.giteaConfig.externalUrl || config.giteaConfig.url;
  if (!baseUrl) {
    return null;
  }

  if (!["mirrored", "mirroring"].includes(organization.status)) {
    return null;
  }

  return `${baseUrl.replace(/\/+$/, "")}/${(
    organization.destinationOrg || organization.name
  ).replace(/^\/+/, "")}`;
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
  countMeta: {
    color: palette.textSoft,
    fontSize: 13,
  },
  countText: {
    color: palette.text,
    fontSize: 15,
    fontWeight: "700",
  },
  errorText: {
    color: palette.danger,
    fontSize: 13,
    lineHeight: 19,
  },
  header: {
    alignItems: "flex-start",
    flexDirection: "row",
    gap: 12,
    justifyContent: "space-between",
  },
  identity: {
    flex: 1,
  },
  metaText: {
    color: palette.textMuted,
    fontSize: 13,
  },
  name: {
    color: palette.text,
    fontSize: 18,
    fontWeight: "800",
  },
  role: {
    color: palette.textSoft,
    fontSize: 13,
    marginTop: 4,
    textTransform: "capitalize",
  },
  stats: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
  },
});
