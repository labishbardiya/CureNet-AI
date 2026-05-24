const fs = require('fs');
const path = require('path');
const Levenshtein = require('fast-levenshtein');

const dictionaryPath = path.join(__dirname, '../../utils/medical_dictionary.json');
let dictionary = [];

try {
  const data = JSON.parse(fs.readFileSync(dictionaryPath, 'utf8'));
  dictionary = data.medications || [];
} catch (e) {
  console.error('[Normalization] Failed to load medical dictionary:', e.message);
}

/**
 * Corrects a drug name using a fuzzy-match against the local dictionary.
 * Rules:
 * - Match if distance is less than 30% of length.
 * - Preserve original if no strong match found.
 */
exports.normalizeMedicineName = (rawName) => {
  if (!rawName || rawName === 'unclear') return rawName;

  let bestMatch = rawName;
  let minDistance = Infinity;
  const threshold = Math.max(2, Math.floor(rawName.length * 0.3));

  for (const drug of dictionary) {
    const dist = Levenshtein.get(rawName.toLowerCase(), drug.toLowerCase());
    if (dist < minDistance) {
      minDistance = dist;
      bestMatch = drug;
    }
  }

  // Return best match only if within threshold, otherwise return raw original
  return (minDistance <= threshold) ? bestMatch : rawName;
};
