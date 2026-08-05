import { Search, X } from 'lucide-react-native';
import { Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { useMemo, useState } from 'react';

import { getDataNatureLabel } from '../core/provenance';
import type { Destination } from '../data/catalog';
import { colors, fontFamilies, radii, spacing } from '../design/tokens';

interface DestinationSheetProps {
  visible: boolean;
  destinations: readonly Destination[];
  selectedDestinationId: string;
  onSelect: (destinationId: string) => void;
  onClose: () => void;
}

export function DestinationSheet({
  visible,
  destinations,
  selectedDestinationId,
  onSelect,
  onClose,
}: DestinationSheetProps) {
  const [query, setQuery] = useState('');
  const filteredDestinations = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) {
      return destinations;
    }

    return destinations.filter((destination) =>
      `${destination.name} ${destination.subtitle} ${destination.category}`
        .toLowerCase()
        .includes(normalized),
    );
  }, [destinations, query]);

  return (
    <Modal animationType="slide" onRequestClose={onClose} transparent visible={visible}>
      <Pressable accessibilityLabel="关闭目的地选择" onPress={onClose} style={styles.backdrop}>
        <View onStartShouldSetResponder={() => true} style={styles.sheet}>
          <View style={styles.sheetHeader}>
            <View>
              <Text style={styles.eyebrow}>导航数据库</Text>
              <Text style={styles.title}>选择目的地</Text>
            </View>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="关闭目的地选择"
              onPress={onClose}
              style={styles.closeButton}
            >
              <X color={colors.textMuted} size={19} strokeWidth={1.8} />
            </Pressable>
          </View>
          <View style={styles.searchBox}>
            <Search color={colors.textQuiet} size={17} strokeWidth={1.8} />
            <TextInput
              accessibilityLabel="搜索目的地"
              autoCapitalize="none"
              onChangeText={setQuery}
              placeholder="搜索恒星、星系或行星系统"
              placeholderTextColor={colors.textQuiet}
              style={styles.searchInput}
              value={query}
            />
          </View>
          <ScrollView
            accessibilityLabel="目的地列表"
            accessibilityRole="radiogroup"
            contentContainerStyle={styles.destinationList}
            keyboardShouldPersistTaps="handled"
          >
            {filteredDestinations.map((destination) => {
              const selected = destination.id === selectedDestinationId;
              return (
                <Pressable
                  accessibilityRole="radio"
                  accessibilityState={{ selected }}
                  accessibilityLabel={`${destination.name}，${destination.subtitle}`}
                  key={destination.id}
                  onPress={() => onSelect(destination.id)}
                  style={({ pressed }) => [
                    styles.destinationRow,
                    selected && styles.selectedRow,
                    pressed && styles.pressed,
                  ]}
                >
                  <View style={[styles.destinationOrb, selected && styles.selectedOrb]}>
                    <View style={styles.orbCore} />
                  </View>
                  <View style={styles.destinationCopy}>
                    <Text style={styles.destinationName}>{destination.name}</Text>
                    <Text style={styles.destinationSubtitle}>{destination.subtitle}</Text>
                  </View>
                  <View style={styles.destinationTag}>
                    <Text style={styles.destinationTagText}>
                      {getDataNatureLabel(destination.catalogProvenance.nature)}
                    </Text>
                    <Text style={styles.destinationTagType}>{destination.category}</Text>
                  </View>
                </Pressable>
              );
            })}
            {filteredDestinations.length === 0 && (
              <Text style={styles.empty}>没有匹配的目的地</Text>
            )}
          </ScrollView>
        </View>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    backgroundColor: 'rgba(0, 0, 0, 0.58)',
    flex: 1,
    justifyContent: 'flex-end',
  },
  sheet: {
    backgroundColor: colors.canvasRaised,
    borderColor: colors.line,
    borderTopLeftRadius: radii.lg,
    borderTopRightRadius: radii.lg,
    borderWidth: 1,
    maxHeight: '82%',
    paddingBottom: spacing.xl,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
  },
  sheetHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  eyebrow: {
    color: colors.cyan,
    fontFamily: fontFamilies.display,
    fontSize: 10,
    letterSpacing: 0.7,
    textTransform: 'uppercase',
  },
  title: {
    color: colors.text,
    fontSize: 22,
    fontWeight: '700',
    marginTop: 3,
  },
  closeButton: {
    alignItems: 'center',
    borderColor: colors.line,
    borderRadius: radii.md,
    borderWidth: 1,
    height: 36,
    justifyContent: 'center',
    width: 36,
  },
  searchBox: {
    alignItems: 'center',
    backgroundColor: 'rgba(3, 7, 12, 0.78)',
    borderColor: colors.line,
    borderRadius: radii.md,
    borderWidth: 1,
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.lg,
    paddingHorizontal: spacing.md,
  },
  searchInput: {
    color: colors.text,
    flex: 1,
    fontSize: 13,
    height: 44,
  },
  destinationList: {
    gap: spacing.sm,
    paddingTop: spacing.md,
  },
  destinationRow: {
    alignItems: 'center',
    backgroundColor: 'rgba(8, 18, 26, 0.68)',
    borderColor: colors.line,
    borderRadius: radii.md,
    borderWidth: 1,
    flexDirection: 'row',
    minHeight: 68,
    paddingHorizontal: spacing.md,
  },
  selectedRow: {
    backgroundColor: 'rgba(83, 221, 234, 0.11)',
    borderColor: 'rgba(83, 221, 234, 0.52)',
  },
  pressed: {
    opacity: 0.76,
  },
  destinationOrb: {
    alignItems: 'center',
    backgroundColor: 'rgba(83, 221, 234, 0.15)',
    borderColor: 'rgba(83, 221, 234, 0.34)',
    borderRadius: radii.pill,
    borderWidth: 1,
    height: 34,
    justifyContent: 'center',
    width: 34,
  },
  selectedOrb: {
    backgroundColor: 'rgba(83, 221, 234, 0.27)',
    borderColor: colors.cyan,
  },
  orbCore: {
    backgroundColor: colors.mint,
    borderRadius: radii.pill,
    height: 9,
    width: 9,
  },
  destinationCopy: {
    flex: 1,
    marginLeft: spacing.md,
    minWidth: 0,
  },
  destinationName: {
    color: colors.text,
    fontSize: 14,
    fontWeight: '700',
  },
  destinationSubtitle: {
    color: colors.textMuted,
    fontSize: 10,
    marginTop: 3,
  },
  destinationTag: {
    alignItems: 'flex-end',
    maxWidth: 88,
  },
  destinationTagText: {
    color: colors.green,
    fontFamily: fontFamilies.display,
    fontSize: 9,
  },
  destinationTagType: {
    color: colors.textQuiet,
    fontSize: 9,
    marginTop: 2,
    textAlign: 'right',
  },
  empty: {
    color: colors.textMuted,
    fontSize: 13,
    paddingVertical: spacing.xl,
    textAlign: 'center',
  },
});
