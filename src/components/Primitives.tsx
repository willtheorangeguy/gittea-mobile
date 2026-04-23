import type { ReactNode } from "react";
import {
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
  type StyleProp,
  type TextInputProps,
  type TextStyle,
  type ViewStyle,
} from "react-native";
import { palette, radius } from "../theme";

interface AppCardProps {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
}

interface AppButtonProps {
  label: string;
  onPress: () => void;
  variant?: "primary" | "secondary" | "ghost" | "danger";
  disabled?: boolean;
  compact?: boolean;
  style?: StyleProp<ViewStyle>;
  textStyle?: StyleProp<TextStyle>;
}

interface FieldProps extends TextInputProps {
  hint?: string;
  label: string;
}

interface MetricCardProps {
  label: string;
  note?: string;
  value: string;
}

interface EmptyStateProps {
  actionLabel?: string;
  onAction?: () => void;
  subtitle: string;
  title: string;
}

export function AppCard({ children, style }: AppCardProps) {
  return <View style={[styles.card, style]}>{children}</View>;
}

export function AppButton({
  label,
  onPress,
  variant = "primary",
  disabled,
  compact,
  style,
  textStyle,
}: AppButtonProps) {
  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.buttonBase,
        compact ? styles.buttonCompact : styles.buttonNormal,
        variant === "primary" && styles.buttonPrimary,
        variant === "secondary" && styles.buttonSecondary,
        variant === "ghost" && styles.buttonGhost,
        variant === "danger" && styles.buttonDanger,
        pressed && !disabled && styles.buttonPressed,
        disabled && styles.buttonDisabled,
        style,
      ]}
    >
      <Text
        style={[
          styles.buttonText,
          variant === "ghost" && styles.buttonTextGhost,
          variant === "secondary" && styles.buttonTextSecondary,
          disabled && styles.buttonTextDisabled,
          textStyle,
        ]}
      >
        {label}
      </Text>
    </Pressable>
  );
}

export function Field({ label, hint, style, ...props }: FieldProps) {
  return (
    <View style={styles.fieldGroup}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput
        placeholderTextColor={palette.textSoft}
        style={[styles.field, style]}
        {...props}
      />
      {hint ? <Text style={styles.fieldHint}>{hint}</Text> : null}
    </View>
  );
}

export function SectionTitle({
  title,
  subtitle,
}: {
  subtitle?: string;
  title: string;
}) {
  return (
    <View style={styles.sectionHeader}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {subtitle ? <Text style={styles.sectionSubtitle}>{subtitle}</Text> : null}
    </View>
  );
}

export function MetricCard({ label, note, value }: MetricCardProps) {
  return (
    <AppCard style={styles.metricCard}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={styles.metricValue}>{value}</Text>
      {note ? <Text style={styles.metricNote}>{note}</Text> : null}
    </AppCard>
  );
}

export function EmptyState({
  actionLabel,
  onAction,
  subtitle,
  title,
}: EmptyStateProps) {
  return (
    <AppCard style={styles.emptyState}>
      <Text style={styles.emptyTitle}>{title}</Text>
      <Text style={styles.emptySubtitle}>{subtitle}</Text>
      {actionLabel && onAction ? (
        <AppButton label={actionLabel} onPress={onAction} style={styles.emptyButton} />
      ) : null}
    </AppCard>
  );
}

const styles = StyleSheet.create({
  buttonBase: {
    alignItems: "center",
    borderRadius: radius.pill,
    flexDirection: "row",
    justifyContent: "center",
  },
  buttonCompact: {
    minHeight: 38,
    paddingHorizontal: 14,
  },
  buttonDanger: {
    backgroundColor: palette.warm,
  },
  buttonDisabled: {
    opacity: 0.48,
  },
  buttonGhost: {
    backgroundColor: palette.accentSoft,
    borderColor: palette.border,
    borderWidth: 1,
  },
  buttonNormal: {
    minHeight: 48,
    paddingHorizontal: 18,
  },
  buttonPressed: {
    transform: [{ scale: 0.985 }],
  },
  buttonPrimary: {
    backgroundColor: palette.accent,
  },
  buttonSecondary: {
    backgroundColor: palette.surfaceBright,
    borderColor: palette.border,
    borderWidth: 1,
  },
  buttonText: {
    color: palette.background,
    fontSize: 15,
    fontWeight: "700",
  },
  buttonTextDisabled: {
    color: palette.textMuted,
  },
  buttonTextGhost: {
    color: palette.text,
  },
  buttonTextSecondary: {
    color: palette.text,
  },
  card: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: radius.md,
    borderWidth: 1,
    overflow: "hidden",
    padding: 18,
    shadowColor: palette.shadow,
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.24,
    shadowRadius: 20,
  },
  emptyButton: {
    marginTop: 16,
  },
  emptyState: {
    alignItems: "center",
    paddingVertical: 28,
  },
  emptySubtitle: {
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 21,
    marginTop: 6,
    textAlign: "center",
  },
  emptyTitle: {
    color: palette.text,
    fontSize: 18,
    fontWeight: "700",
  },
  field: {
    backgroundColor: palette.backgroundElevated,
    borderColor: palette.border,
    borderRadius: radius.sm,
    borderWidth: 1,
    color: palette.text,
    fontSize: 15,
    minHeight: 50,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  fieldGroup: {
    gap: 8,
  },
  fieldHint: {
    color: palette.textSoft,
    fontSize: 12,
    lineHeight: 18,
  },
  fieldLabel: {
    color: palette.text,
    fontSize: 13,
    fontWeight: "700",
    letterSpacing: 0.4,
    textTransform: "uppercase",
  },
  metricCard: {
    flex: 1,
    minWidth: 0,
  },
  metricLabel: {
    color: palette.textMuted,
    fontSize: 12,
    fontWeight: "700",
    letterSpacing: 0.5,
    textTransform: "uppercase",
  },
  metricNote: {
    color: palette.textSoft,
    fontSize: 12,
    marginTop: 6,
  },
  metricValue: {
    color: palette.text,
    fontSize: 28,
    fontWeight: "800",
    marginTop: 12,
  },
  sectionHeader: {
    gap: 4,
    marginBottom: 14,
  },
  sectionSubtitle: {
    color: palette.textMuted,
    fontSize: 14,
  },
  sectionTitle: {
    color: palette.text,
    fontSize: 22,
    fontWeight: "800",
  },
});
