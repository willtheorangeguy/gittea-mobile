import { LinearGradient } from "expo-linear-gradient";
import {
  KeyboardAvoidingView,
  Platform,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { AppButton, AppCard, Field } from "../components/Primitives";
import { palette } from "../theme";

interface ConnectScreenProps {
  busyLabel: string | null;
  errorMessage: string | null;
  instanceUrl: string;
  onConnect: () => void;
  onInstanceUrlChange: (value: string) => void;
}

export function ConnectScreen({
  busyLabel,
  errorMessage,
  instanceUrl,
  onConnect,
  onInstanceUrlChange,
}: ConnectScreenProps) {
  return (
    <LinearGradient
      colors={[palette.background, palette.backgroundElevated, "#163732"]}
      style={styles.gradient}
    >
      <SafeAreaView style={styles.safeArea}>
        <KeyboardAvoidingView
          behavior={Platform.OS === "ios" ? "padding" : undefined}
          style={styles.keyboard}
        >
          <ScrollView contentContainerStyle={styles.content}>
            <View style={styles.hero}>
              <Text style={styles.eyebrow}>Windows-friendly iPhone workflow</Text>
              <Text style={styles.title}>Connect to your Gitea Mirror instance.</Text>
              <Text style={styles.subtitle}>
                This mobile client talks directly to the same self-hosted instance
                you already manage in the browser.
              </Text>
            </View>

            <AppCard>
              <Field
                autoCapitalize="none"
                autoCorrect={false}
                hint="Use the full public URL if your instance lives behind a reverse proxy or base path."
                keyboardType="url"
                label="Instance URL"
                onChangeText={onInstanceUrlChange}
                placeholder="https://mirror.example.com"
                value={instanceUrl}
              />

              {errorMessage ? <Text style={styles.error}>{errorMessage}</Text> : null}

              <AppButton
                disabled={Boolean(busyLabel)}
                label={busyLabel || "Continue"}
                onPress={onConnect}
                style={styles.primaryButton}
              />
            </AppCard>

            <AppCard style={styles.noteCard}>
              <Text style={styles.noteTitle}>iPhone test note</Text>
              <Text style={styles.noteBody}>
                Expo Go works well from Windows, but the phone still has to reach
                your instance over a trusted network path. HTTPS is strongly
                recommended.
              </Text>
            </AppCard>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  content: {
    flexGrow: 1,
    gap: 18,
    justifyContent: "center",
    padding: 20,
  },
  eyebrow: {
    color: palette.accent,
    fontSize: 13,
    fontWeight: "800",
    letterSpacing: 1.2,
    textTransform: "uppercase",
  },
  error: {
    color: palette.danger,
    fontSize: 13,
    lineHeight: 19,
    marginTop: 14,
  },
  gradient: {
    flex: 1,
  },
  hero: {
    gap: 10,
  },
  keyboard: {
    flex: 1,
  },
  noteBody: {
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 21,
    marginTop: 10,
  },
  noteCard: {
    backgroundColor: palette.surfaceMuted,
  },
  noteTitle: {
    color: palette.text,
    fontSize: 17,
    fontWeight: "800",
  },
  primaryButton: {
    marginTop: 18,
  },
  safeArea: {
    flex: 1,
  },
  subtitle: {
    color: palette.textMuted,
    fontSize: 16,
    lineHeight: 24,
    maxWidth: 440,
  },
  title: {
    color: palette.text,
    fontSize: 34,
    fontWeight: "900",
    lineHeight: 40,
    maxWidth: 520,
  },
});
