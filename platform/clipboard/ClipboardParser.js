.pragma library

function parseList(text) {
    const entries = [];
    const lines = String(text || "").split(/\r?\n/);

    for (const line of lines) {
        if (line.trim().length === 0)
            continue;

        const separator = line.indexOf("\t");
        if (separator <= 0)
            continue;

        const id = line.slice(0, separator).trim();
        const preview = line.slice(separator + 1);
        if (id.length === 0)
            continue;

        entries.push({
            "id": id,
            "preview": preview,
            "rawLine": line
        });
    }

    return entries;
}
