import { useState } from "react";
import {
  Modal,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { AppButton, AppCard, EmptyState, Field, SectionTitle } from "../components/Primitives";
import { OrganizationRow } from "../components/OrganizationRow";
import type {
  AppConfigResponse,
  MembershipRole,
  MirrorOrganization,
} from "../types/giteaMirror";
import { palette, radius } from "../theme";

interface OrganizationsTabProps {
  busyOrganizationId: string | null;
  config: AppConfigResponse | null;
  onAddOrganization: (input: {
    org: string;
    role: MembershipRole;
  }) => Promise<boolean>;
  onIgnore: (organizationId: string) => void;
  onInclude: (organizationId: string) => void;
  onMirror: (organizationId: string) => void;
  onRefresh: () => void;
  organizations: MirrorOrganization[];
  refreshing: boolean;
}

export function OrganizationsTab({
  busyOrganizationId,
  config,
  onAddOrganization,
  onIgnore,
  onInclude,
  onMirror,
  onRefresh,
  organizations,
  refreshing,
}: OrganizationsTabProps) {
  const [query, setQuery] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [org, setOrg] = useState("");
  const [role, setRole] = useState<MembershipRole>("member");
  const [submitting, setSubmitting] = useState(false);

  const filteredOrganizations = organizations.filter((item) => {
    const search = `${item.name} ${item.membershipRole}`.toLowerCase();
    const normalizedQuery = query.trim().toLowerCase();
    return !normalizedQuery || search.includes(normalizedQuery);
  });

  async function handleAdd() {
    setSubmitting(true);
    const success = await onAddOrganization({ org, role });
    setSubmitting(false);

    if (success) {
      setOrg("");
      setRole("member");
      setShowModal(false);
    }
  }

  return (
    <>
      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={palette.accent} />
        }
      >
        <AppCard style={styles.toolbar}>
          <SectionTitle
            subtitle="Monitor imported organizations and start organization-wide mirrors."
            title="Organizations"
          />
          <Field
            autoCapitalize="none"
            autoCorrect={false}
            label="Search"
            onChangeText={setQuery}
            placeholder="Organization name"
            value={query}
          />
          <AppButton label="Add Organization" onPress={() => setShowModal(true)} />
        </AppCard>

        {filteredOrganizations.length === 0 ? (
          <EmptyState
            actionLabel="Add Organization"
            onAction={() => setShowModal(true)}
            subtitle="Import a GitHub organization to manage it from mobile."
            title="No organizations yet"
          />
        ) : (
          <View style={styles.list}>
            {filteredOrganizations.map((organization) => (
              <OrganizationRow
                busy={busyOrganizationId === organization.id}
                config={config}
                key={organization.id}
                onIgnore={onIgnore}
                onInclude={onInclude}
                onMirror={onMirror}
                organization={organization}
              />
            ))}
          </View>
        )}
      </ScrollView>

      <Modal animationType="slide" onRequestClose={() => setShowModal(false)} transparent visible={showModal}>
        <View style={styles.modalBackdrop}>
          <AppCard style={styles.modalCard}>
            <Text style={styles.modalTitle}>Add Organization</Text>
            <Text style={styles.modalSubtitle}>
              Import an organization and its repositories into Gitea Mirror.
            </Text>
            <Field
              autoCapitalize="none"
              autoCorrect={false}
              label="Organization"
              onChangeText={setOrg}
              placeholder="RayLabsHQ"
              value={org}
            />

            <Text style={styles.roleLabel}>Membership Role</Text>
            <View style={styles.roleRow}>
              {(["member", "admin", "owner", "billing_manager"] as const).map(
                (option) => (
                  <AppButton
                    compact
                    key={option}
                    label={option.replace("_", " ")}
                    onPress={() => setRole(option)}
                    variant={role === option ? "primary" : "ghost"}
                  />
                ),
              )}
            </View>

            <View style={styles.modalActions}>
              <AppButton label="Cancel" onPress={() => setShowModal(false)} variant="secondary" />
              <AppButton
                label={submitting ? "Adding" : "Add"}
                onPress={handleAdd}
                style={styles.modalPrimary}
              />
            </View>
          </AppCard>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  content: {
    gap: 16,
    padding: 18,
    paddingBottom: 120,
  },
  list: {
    gap: 12,
  },
  modalActions: {
    gap: 10,
    marginTop: 18,
  },
  modalBackdrop: {
    backgroundColor: palette.overlay,
    flex: 1,
    justifyContent: "flex-end",
    padding: 18,
  },
  modalCard: {
    borderRadius: radius.lg,
  },
  modalPrimary: {
    marginTop: 0,
  },
  modalSubtitle: {
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 21,
    marginBottom: 16,
  },
  modalTitle: {
    color: palette.text,
    fontSize: 22,
    fontWeight: "800",
    marginBottom: 6,
  },
  roleLabel: {
    color: palette.text,
    fontSize: 13,
    fontWeight: "800",
    letterSpacing: 0.5,
    marginTop: 16,
    textTransform: "uppercase",
  },
  roleRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
    marginTop: 10,
  },
  toolbar: {
    gap: 14,
  },
});
