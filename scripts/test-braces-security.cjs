const assert = require('node:assert/strict');
const braces = require('braces');

const nested = depth => '{'.repeat(depth) + 'a,b' + '}'.repeat(depth);
const maliciousPattern = nested(101);
const safePattern = nested(100);

assert.throws(() => braces(maliciousPattern), /exceeds max depth/);
assert.throws(() => braces.parse(maliciousPattern), /exceeds max depth/);
assert.throws(() => braces.compile(maliciousPattern), /exceeds max depth/);
assert.throws(() => braces.expand(maliciousPattern), /exceeds max depth/);
assert.throws(() => braces.stringify(maliciousPattern), /exceeds max depth/);

assert.doesNotThrow(() => braces.parse(safePattern));
assert.deepEqual(braces('{a,b}', { expand: true }), ['a', 'b']);
assert.deepEqual(braces.expand('{a,b}'), ['a', 'b']);

console.log('braces rejects excessive nesting and preserves normal expansion');
