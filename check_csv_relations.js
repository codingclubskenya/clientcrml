const fs = require('fs');

// Read CSV files
const usersCsv = fs.readFileSync('users_rows.csv', 'utf8');
const schoolsCsv = fs.readFileSync('12.csv', 'utf8');

// Simple CSV parsing
function parseCsv(csv) {
  const lines = csv.trim().split('\n');
  const headers = lines[0].split(',');
  return lines.slice(1).map(line => {
    const values = line.split(',');
    const obj = {};
    headers.forEach((h, i) => {
      obj[h.trim()] = values[i] ? values[i].trim() : '';
    });
    return obj;
  });
}

const users = parseCsv(usersCsv);
const schools = parseCsv(schoolsCsv);

// Build user ID set
const userIds = new Set(users.map(u => u.id));

// Check captured_by references
const capturedByValues = new Set();
const orphanedSchools = [];
const schoolsWithoutCapturedBy = [];

for (const s of schools) {
  const cb = s.captured_by || '';
  if (cb && cb.trim()) {
    const trimmed = cb.trim();
    capturedByValues.add(trimmed);
    if (!userIds.has(trimmed)) {
      orphanedSchools.push({ id: s.id, name: s.name, captured_by: trimmed });
    }
  } else {
    schoolsWithoutCapturedBy.push({ id: s.id, name: s.name });
  }
}

console.log('Total users in CSV:', userIds.size);
console.log('Total schools in CSV:', schools.length);
console.log('Unique captured_by values:', capturedByValues.size);
console.log('Orphaned schools (captured_by not in users):', orphanedSchools.length);
console.log('Schools without captured_by:', schoolsWithoutCapturedBy.length);

if (orphanedSchools.length > 0) {
  console.log('\nOrphaned schools (first 10):');
  orphanedSchools.slice(0, 10).forEach(s => {
    console.log(`  ${s.id} | ${s.name} | captured_by: ${s.captured_by}`);
  });
}

if (schoolsWithoutCapturedBy.length > 0) {
  console.log('\nSchools without captured_by (first 10):');
  schoolsWithoutCapturedBy.slice(0, 10).forEach(s => {
    console.log(`  ${s.id} | ${s.name}`);
  });
}
