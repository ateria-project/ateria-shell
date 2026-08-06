.pragma library

function normalize(value) {
    return String(value || "").toLocaleLowerCase().replace(/\s+/g, " ").trim();
}

function filterEntries(entries, query) {
    const source = Array.isArray(entries) ? entries : [];
    const normalizedQuery = normalize(query);
    if (normalizedQuery.length === 0)
        return source;

    const terms = normalizedQuery.split(" ");
    return source.filter(entry => {
        const preview = normalize(entry && entry.preview);
        return terms.every(term => preview.includes(term));
    });
}
