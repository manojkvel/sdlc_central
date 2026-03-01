/**
 * Minimal YAML parser using only Node.js builtins.
 * Handles: flat key-value, quoted strings, inline arrays [a, b],
 * indentation-based nesting, sequence-of-maps (- id: foo).
 * NOT a full YAML spec — just enough for skill.yaml and pipeline YAML.
 */
'use strict';

function parseYaml(text) {
  const lines = text.split('\n');
  return parseLines(lines, 0, 0).value;
}

function parseLines(lines, start, baseIndent) {
  const result = {};
  let i = start;
  let isSequence = false;
  let sequenceArray = [];

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trimStart();

    // Skip empty lines and comments
    if (!trimmed || trimmed.startsWith('#')) {
      i++;
      continue;
    }

    const indent = line.length - trimmed.length;

    // If less indented than our base, we're done with this block
    if (indent < baseIndent) {
      break;
    }

    // Sequence item (- key: value or - value)
    if (trimmed.startsWith('- ')) {
      if (indent === baseIndent) {
        isSequence = true;
        const itemContent = trimmed.slice(2);

        // Check if it's a map item (- key: value)
        const colonIdx = itemContent.indexOf(':');
        if (colonIdx > 0 && !itemContent.startsWith('"') && !itemContent.startsWith("'")) {
          // It's a map entry in a sequence — parse as nested map
          const mapItem = {};
          const key = itemContent.slice(0, colonIdx).trim();
          const val = itemContent.slice(colonIdx + 1).trim();
          mapItem[key] = parseValue(val);

          // Check for continuation lines at deeper indent
          let j = i + 1;
          while (j < lines.length) {
            const nextLine = lines[j];
            const nextTrimmed = nextLine.trimStart();
            if (!nextTrimmed || nextTrimmed.startsWith('#')) {
              j++;
              continue;
            }
            const nextIndent = nextLine.length - nextTrimmed.length;
            if (nextIndent <= indent) break;
            // Nested key:value in the same map item
            const nc = nextTrimmed.indexOf(':');
            if (nc > 0) {
              const nk = nextTrimmed.slice(0, nc).trim();
              const nv = nextTrimmed.slice(nc + 1).trim();
              if (nk === 'on_fail' && (nv === '' || nv === '|')) {
                // Nested map under on_fail
                const nested = parseLines(lines, j + 1, nextIndent + 2);
                mapItem[nk] = nested.value;
                j = nested.nextIndex;
              } else {
                mapItem[nk] = parseValue(nv);
                j++;
              }
            } else {
              break;
            }
          }
          sequenceArray.push(mapItem);
          i = j;
        } else {
          // Simple sequence value
          sequenceArray.push(parseValue(itemContent));
          i++;
        }
        continue;
      }
    }

    // Key: value pair
    const colonIdx = trimmed.indexOf(':');
    if (colonIdx > 0) {
      const key = trimmed.slice(0, colonIdx).trim();
      const rawVal = trimmed.slice(colonIdx + 1).trim();

      if (rawVal === '' || rawVal === '|' || rawVal === '>') {
        // Nested block — look ahead for indented content
        const nextNonEmpty = findNextNonEmpty(lines, i + 1);
        if (nextNonEmpty < lines.length) {
          const nextIndent = lines[nextNonEmpty].length - lines[nextNonEmpty].trimStart().length;
          if (nextIndent > indent) {
            // Check if next content starts with '- ' (sequence)
            const nextTrimmed = lines[nextNonEmpty].trimStart();
            if (nextTrimmed.startsWith('- ')) {
              const nested = parseLines(lines, nextNonEmpty, nextIndent);
              result[key] = nested.isSequence ? nested.sequenceArray : nested.value;
              i = nested.nextIndex;
            } else {
              const nested = parseLines(lines, nextNonEmpty, nextIndent);
              result[key] = nested.isSequence ? nested.sequenceArray : nested.value;
              i = nested.nextIndex;
            }
          } else {
            result[key] = rawVal === '|' || rawVal === '>' ? '' : null;
            i++;
          }
        } else {
          result[key] = null;
          i++;
        }
      } else {
        result[key] = parseValue(rawVal);
        i++;
      }
    } else {
      i++;
    }
  }

  return {
    value: isSequence ? sequenceArray : result,
    isSequence,
    sequenceArray,
    nextIndex: i,
  };
}

function findNextNonEmpty(lines, start) {
  let i = start;
  while (i < lines.length) {
    const trimmed = lines[i].trimStart();
    if (trimmed && !trimmed.startsWith('#')) return i;
    i++;
  }
  return i;
}

function parseValue(raw) {
  if (!raw) return null;

  // Quoted strings
  if ((raw.startsWith('"') && raw.endsWith('"')) ||
      (raw.startsWith("'") && raw.endsWith("'"))) {
    return raw.slice(1, -1);
  }

  // Inline array [a, b, c]
  if (raw.startsWith('[') && raw.endsWith(']')) {
    const inner = raw.slice(1, -1).trim();
    if (!inner) return [];
    return inner.split(',').map(s => {
      const t = s.trim();
      if ((t.startsWith('"') && t.endsWith('"')) ||
          (t.startsWith("'") && t.endsWith("'"))) {
        return t.slice(1, -1);
      }
      return t;
    });
  }

  // Booleans
  if (raw === 'true') return true;
  if (raw === 'false') return false;

  // Null
  if (raw === 'null' || raw === '~') return null;

  // Numbers
  if (/^-?\d+$/.test(raw)) return parseInt(raw, 10);
  if (/^-?\d+\.\d+$/.test(raw)) return parseFloat(raw);

  return raw;
}

module.exports = { parseYaml };
