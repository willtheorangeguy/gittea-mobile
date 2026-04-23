import { LinearGradient } from "expo-linear-gradient";
import { useState } from "react";
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
import { normalizeDisplayUrl } from "../lib/format";
import { palette } from "../theme";

interface LoginScreenProps {
  busyLabel: string | null;
  errorMessage: string | null;
  instanceUrl: string;
  onBack: () => void;
  onLogin: (email: string, password: string) => void;
  savedEmail: string;
}

export function LoginScreen({
  busyLabel,
  errorMessage,
  instanceUrl,
  onBack,
  onLogin,
  savedEmail,
}: LoginScreenProps) {
  const [email, setEmail] = useState(savedEmail);
  const [password, setPassword] = useState("");

  return (
    <LinearGradient
      colors={[palette.background, "#102422", "#173631"]}
      style={styles.gradient}
    >
      <SafeAreaView style={styles.safeArea}>
        <KeyboardAvoidingView
          behavior={Platform.OS === "ios" ? "padding" : undefined}
          style={styles.keyboard}
        >
          <ScrollView contentContainerStyle={styles.content}>
            <View style={styles.hero}>
              <Text style={styles.eyebrow}>Connected instance</Text>
              <Text style={styles.instance}>{normalizeDisplayUrl(instanceUrl)}</Text>
              <Text style={styles.title}>Sign in with your Gitea Mirror account.</Text>
            </View>

            <AppCard>
              <Field
                autoCapitalize="none"
                autoCorrect={false}
                keyboardType="email-address"
                label="Email"
                onChangeText={setEmail}
                placeholder="you@example.com"
                value={email}
              />
              <View style={styles.spacer} />
              <Field
                autoCapitalize="none"
                autoCorrect={false}
                label="Password"
                onChangeText={setPassword}
                placeholder="Your account password"
                secureTextEntry
                value={password}
              />

              {errorMessage ? <Text style={styles.error}>{errorMessage}</Text> : null}

              <View style={styles.actions}>
                <AppButton
                  disabled={Boolean(busyLabel)}
                  label="Change Instance"
                  onPress={onBack}
                  style={styles.secondary}
                  variant="secondary"
                />
                <AppButton
                  disabled={Boolean(busyLabel)}
                  label={busyLabel || "Sign In"}
                  onPress={() => onLogin(email, password)}
                  style={styles.primary}
                />
              </View>
            </AppCard>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  actions: {
    gap: 12,
    marginTop: 18,
  },
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
  instance: {
    color: palette.text,
    fontSize: 18,
    fontWeight: "800",
  },
  keyboard: {
    flex: 1,
  },
  primary: {
    marginTop: 0,
  },
  safeArea: {
    flex: 1,
  },
  secondary: {
    marginTop: 0,
  },
  spacer: {
    height: 14,
  },
  title: {
    color: palette.textMuted,
    fontSize: 16,
    lineHeight: 24,
    maxWidth: 460,
  },
});
