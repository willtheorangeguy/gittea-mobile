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
import { RepositoryRow } from "../components/RepositoryRow";
import type { AppConfigResponse, MirrorRepository } from "../types/giteaMirror";
import { palette, radius } from "../theme";

interface RepositoriesTabProps {
  busyRepositoryId: string | null;
  config: AppConfigResponse | null;
  onAddRepository: (input: { owner: string; repo: string }) => Promise<boolean>;
  onApprove: (repositoryId: string) => void;
  onDismiss: (repositoryId: string) => void;
  onIgnore: (repositoryId: string) => void;
  onInclude: (repositoryId: string) => void;
  onMirror: (repositoryId: string) => void;
  onRefresh: () => void;
  onRetry: (repositoryId: string) => void;
  onSync: (repositoryId: string) => void;
  refreshing: boolean;
  repositories: MirrorRepository[];
}

const filters = [
  { key: "all", label: "All" },
  { key: "needs-action", label: "Needs Action" },
  { key: "active", label: "Active" },
  { key: "healthy", label: "Healthy" },
  { key: "ignored", label: "Ignored" },
] as const;

type FilterKey = (typeof filters)[number]["key"];

export function RepositoriesTab({
  busyRepositoryId,
  config,
  onAddRepository,
  onApprove,
  onDismiss,
  onIgnore,
  onInclude,
  onMirror,
  onRefresh,
  onRetry,
  onSync,
  refreshing,
  repositories,
}: RepositoriesTabProps) {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<FilterKey>("all");
  const [showModal, setShowModal] = useState(false);
  const [owner, setOwner] = useState("");
  const [repo, setRepo] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const filteredRepositories = repositories.filter((item) => {
    const search = `${item.fullName} ${item.description || ""}`.toLowerCase();
    const normalizedQuery = query.trim().toLowerCase();
    const queryMatch = !normalizedQuery || search.includes(normalizedQuery);

    const filterMatch =
      filter === "all" ||
      (filter === "needs-action" &&
        ["imported", "failed", "pending-approval"].includes(item.status)) ||
      (filter === "active" && ["mirroring", "syncing"].includes(item.status)) ||
      (filter === "healthy" && ["mirrored", "synced", "archived"].includes(item.status)) ||
      (filter === "ignored" && item.status === "ignored");

    return queryMatch && filterMatch;
  });

  async function handleAdd() {
    setSubmitting(true);
    const success = await onAddRepository({ owner, repo });
    setSubmitting(false);

    if (success) {
      setOwner("");
      setRepo("");
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
            subtitle="Search tracked repositories and trigger mirror actions."
            title="Repositories"
          />
          <Field
            autoCapitalize="none"
            autoCorrect={false}
            label="Search"
            onChangeText={setQuery}
            placeholder="owner/repository"
            value={query}
          />

          <View style={styles.filterRow}>
            {filters.map((option) => (
              <AppButton
                compact
                key={option.key}
                label={option.label}
                onPress={() => setFilter(option.key)}
                style={filter === option.key ? styles.filterActive : styles.filterButton}
                textStyle={filter === option.key ? styles.filterTextActive : undefined}
                variant={filter === option.key ? "primary" : "ghost"}
              />
            ))}
          </View>

          <AppButton label="Add Repository" onPress={() => setShowModal(true)} />
        </AppCard>

        {filteredRepositories.length === 0 ? (
          <EmptyState
            actionLabel="Add Repository"
            onAction={() => setShowModal(true)}
            subtitle="Try a different filter, or add a repository manually."
            title="No repositories match"
          />
        ) : (
          <View style={styles.list}>
            {filteredRepositories.map((repository) => (
              <RepositoryRow
                busy={busyRepositoryId === repository.id}
                config={config}
                key={repository.id}
                onApprove={onApprove}
                onDismiss={onDismiss}
                onIgnore={onIgnore}
                onInclude={onInclude}
                onMirror={onMirror}
                onRetry={onRetry}
                onSync={onSync}
                repository={repository}
              />
            ))}
          </View>
        )}
      </ScrollView>

      <Modal animationType="slide" onRequestClose={() => setShowModal(false)} transparent visible={showModal}>
        <View style={styles.modalBackdrop}>
          <AppCard style={styles.modalCard}>
            <Text style={styles.modalTitle}>Add Repository</Text>
            <Text style={styles.modalSubtitle}>
              Import a specific GitHub repository into Gitea Mirror.
            </Text>
            <Field
              autoCapitalize="none"
              autoCorrect={false}
              label="Owner"
              onChangeText={setOwner}
              placeholder="RayLabsHQ"
              value={owner}
            />
            <View style={styles.modalSpacer} />
            <Field
              autoCapitalize="none"
              autoCorrect={false}
              label="Repository"
              onChangeText={setRepo}
              placeholder="gitea-mirror"
              value={repo}
            />
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
  filterActive: {
    minWidth: 0,
  },
  filterButton: {
    minWidth: 0,
  },
  filterRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
    marginTop: 6,
  },
  filterTextActive: {
    color: palette.background,
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
  modalSpacer: {
    height: 14,
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
  toolbar: {
    gap: 14,
  },
});
