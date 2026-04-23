import { StyleSheet, Text, View } from "react-native";
import { formatStatusLabel } from "../lib/format";
import { palette, radius } from "../theme";

export function StatusBadge({ status }: { status: string }) {
  const colors = getStatusColors(status);

  return (
    <View style={[styles.badge, { backgroundColor: colors.background }]}>
      <Text style={[styles.label, { color: colors.text }]}>
        {formatStatusLabel(status)}
      </Text>
    </View>
  );
}

function getStatusColors(status: string) {
  switch (status) {
    case "mirrored":
    case "synced":
      return { background: palette.successSoft, text: palette.success };
    case "mirroring":
    case "syncing":
      return { background: palette.accentSoft, text: palette.accent };
    case "failed":
      return { background: palette.warmSoft, text: palette.danger };
    case "ignored":
      return { background: "rgba(164, 197, 190, 0.16)", text: palette.textMuted };
    case "pending-approval":
      return { background: palette.cautionSoft, text: palette.caution };
    default:
      return { background: palette.surfaceBright, text: palette.text };
  }
}

const styles = StyleSheet.create({
  badge: {
    alignSelf: "flex-start",
    borderRadius: radius.pill,
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  label: {
    fontSize: 12,
    fontWeight: "800",
    letterSpacing: 0.3,
  },
});
