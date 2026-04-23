import { StyleSheet, Text, View } from "react-native";
import type { MirrorJob } from "../types/giteaMirror";
import { AppCard } from "./Primitives";
import { StatusBadge } from "./StatusBadge";
import { formatRelativeTime } from "../lib/format";
import { palette } from "../theme";

export function ActivityRow({ activity }: { activity: MirrorJob }) {
  const title =
    activity.repositoryName ||
    activity.organizationName ||
    activity.message ||
    "Mirror job";

  return (
    <AppCard style={styles.card}>
      <View style={styles.header}>
        <Text style={styles.title}>{title}</Text>
        <StatusBadge status={activity.status} />
      </View>
      <Text style={styles.message}>{activity.message}</Text>
      {activity.details ? <Text style={styles.details}>{activity.details}</Text> : null}
      <View style={styles.footer}>
        <Text style={styles.meta}>{activity.jobType || "mirror"}</Text>
        <Text style={styles.meta}>{formatRelativeTime(activity.timestamp)}</Text>
      </View>
    </AppCard>
  );
}

const styles = StyleSheet.create({
  card: {
    gap: 10,
  },
  details: {
    color: palette.textSoft,
    fontSize: 13,
    lineHeight: 19,
  },
  footer: {
    flexDirection: "row",
    justifyContent: "space-between",
  },
  header: {
    alignItems: "flex-start",
    flexDirection: "row",
    gap: 12,
    justifyContent: "space-between",
  },
  message: {
    color: palette.text,
    fontSize: 15,
    lineHeight: 22,
  },
  meta: {
    color: palette.textSoft,
    fontSize: 12,
    fontWeight: "600",
    textTransform: "uppercase",
  },
  title: {
    color: palette.text,
    flex: 1,
    fontSize: 16,
    fontWeight: "800",
  },
});
