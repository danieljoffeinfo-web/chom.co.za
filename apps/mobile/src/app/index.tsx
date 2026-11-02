import { colors, minTouchTarget, radius, space, textStyles } from '@chom/tokens';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

const theme = colors.light;

/** Placeholder welcome screen until sign-in is built. */
export default function Welcome() {
  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.content}>
        <Text style={styles.brand}>chom learn</Text>
        <View style={styles.hero}>
          <Text style={styles.title}>Everything at your fingertips.</Text>
          <Text style={styles.lede}>
            <Text style={styles.ledeStrong}>Study the right way with Chom.</Text> Your tasks, classes
            and assignments in one place, so you can focus on learning.
          </Text>
        </View>
        <Pressable
          accessibilityRole="button"
          accessibilityHint="Sign-in is not available yet"
          style={({ pressed }) => [styles.button, pressed && styles.buttonPressed]}
        >
          <Text style={styles.buttonText}>Sign in</Text>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: theme.background },
  content: { flex: 1, padding: space[6], justifyContent: 'space-between' },
  brand: {
    fontFamily: 'InterTight_800ExtraBold',
    fontSize: 22,
    letterSpacing: -1,
    color: theme.text,
  },
  hero: { gap: space[4] },
  title: {
    fontFamily: 'InterTight_800ExtraBold',
    fontSize: 44,
    lineHeight: 46,
    letterSpacing: -1.5,
    color: theme.text,
  },
  lede: {
    fontFamily: 'InterTight_500Medium',
    fontSize: textStyles.body.fontSize,
    lineHeight: textStyles.body.lineHeight,
    color: theme.text,
  },
  ledeStrong: { fontFamily: 'InterTight_800ExtraBold' },
  button: {
    minHeight: minTouchTarget + 8,
    borderRadius: radius.pill,
    backgroundColor: theme.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonPressed: { backgroundColor: theme.primaryHover },
  buttonText: {
    fontFamily: 'InterTight_800ExtraBold',
    fontSize: 16,
    color: theme.onPrimary,
  },
});
