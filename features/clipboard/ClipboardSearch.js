.pragma library

function normalize(value) {
    return String(value || "").toLocaleLowerCase().replace(/\s+/g, " ").trim();
}

function createEntryIndex(entries) {
    const source = Array.isArray(entries) ? entries : [];
    return {
        "entries": source,
        "records": source.map(entry => ({
            "entry": entry,
            "normalizedPreview": normalize(entry && entry.preview)
        }))
    };
}

function filterEntryIndex(index, query) {
    const source = index && Array.isArray(index.entries) ? index.entries : [];
    const normalizedQuery = normalize(query);
    if (normalizedQuery.length === 0)
        return source;

    const terms = normalizedQuery.split(" ");
    const records = index && Array.isArray(index.records) ? index.records : [];
    const results = [];
    for (const record of records) {
        if (terms.every(term => record.normalizedPreview.includes(term)))
            results.push(record.entry);
    }
    return results;
}

function filterEntries(entries, query) {
    return filterEntryIndex(createEntryIndex(entries), query);
}
