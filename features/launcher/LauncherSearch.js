.pragma library

var DAY_IN_MILLISECONDS = 24 * 60 * 60 * 1000;
var MAXIMUM_USAGE_BOOST = 28;
var EMPTY_USAGE_DATA = { "boost": 0, "count": 0, "lastLaunched": 0 };

function normalizeText(value) {
    let normalized = String(value || "").toLocaleLowerCase();

    // Treat accented characters as their unaccented counterparts and desktop
    // entry separators as spaces. This makes queries such as "resume" match
    // "Résumé" and "org gnome terminal" match a desktop entry id.
    if (typeof normalized.normalize === "function")
        normalized = normalized.normalize("NFKD").replace(/[\u0300-\u036f]/g, "");

    return normalized.replace(/[._/\\-]+/g, " ").replace(/\s+/g, " ").trim();
}

function prepareText(value) {
    const normalized = normalizeText(value);
    const textWords = normalized.length > 0 ? normalized.split(" ") : [];

    return {
        "normalized": normalized,
        "words": textWords,
        "compact": normalized.replace(/\s+/g, ""),
        "acronym": textWords.map(word => word.charAt(0)).join("")
    };
}

function prepareQuery(value) {
    const normalized = normalizeText(value);
    return {
        "normalized": normalized,
        "terms": normalized.length > 0 ? normalized.split(" ") : []
    };
}

function listText(value) {
    if (!value)
        return "";

    if (Array.isArray(value))
        return value.join(" ");

    if (typeof value.join === "function")
        return value.join(" ");

    return String(value);
}

function maximumEditDistance(length) {
    if (length < 3)
        return 0;

    return Math.min(3, Math.floor((length + 2) / 4));
}

// Optimal-string-alignment distance catches insertions, omissions, replacements,
// and adjacent transpositions while abandoning comparisons that are already too
// far apart to be useful.
function editDistance(left, right, limit) {
    if (left === right)
        return 0;

    if (Math.abs(left.length - right.length) > limit)
        return limit + 1;

    // Only the current and previous two rows are needed. Keeping three rows
    // avoids allocating a complete matrix for every fuzzy candidate.
    let twoRowsAgo = null;
    let previousRow = [];
    let currentRow = [];
    for (let column = 0; column <= right.length; ++column)
        previousRow[column] = column;

    for (let row = 1; row <= left.length; ++row) {
        currentRow[0] = row;
        let rowMinimum = row;

        for (let column = 1; column <= right.length; ++column) {
            const substitutionCost = left.charAt(row - 1) === right.charAt(column - 1) ? 0 : 1;
            let distance = Math.min(previousRow[column] + 1, currentRow[column - 1] + 1, previousRow[column - 1] + substitutionCost);

            if (twoRowsAgo && column > 1 && left.charAt(row - 1) === right.charAt(column - 2) && left.charAt(row - 2) === right.charAt(column - 1))
                distance = Math.min(distance, twoRowsAgo[column - 2] + 1);

            currentRow[column] = distance;
            rowMinimum = Math.min(rowMinimum, distance);
        }

        if (rowMinimum > limit)
            return limit + 1;

        const reusableRow = twoRowsAgo;
        twoRowsAgo = previousRow;
        previousRow = currentRow;
        currentRow = reusableRow || [];
    }

    return previousRow[right.length];
}

function subsequenceScore(needle, haystack) {
    if (needle.length < 2)
        return Infinity;

    let nextHaystackIndex = 0;
    let firstMatch = -1;
    let previousMatch = -1;
    let gapCost = 0;
    let boundaryMatches = 0;

    for (let needleIndex = 0; needleIndex < needle.length; ++needleIndex) {
        const matchIndex = haystack.indexOf(needle.charAt(needleIndex), nextHaystackIndex);
        if (matchIndex < 0)
            return Infinity;

        if (firstMatch < 0)
            firstMatch = matchIndex;

        if (previousMatch >= 0 && matchIndex !== previousMatch + 1)
            gapCost += 6 + Math.max(0, matchIndex - previousMatch - 2) * 2;

        if (matchIndex === 0 || haystack.charAt(matchIndex - 1) === " ")
            boundaryMatches++;

        previousMatch = matchIndex;
        nextHaystackIndex = matchIndex + 1;
    }

    const span = previousMatch - firstMatch + 1;
    if (needle.length < 5 && span > needle.length * 3)
        return Infinity;

    return 210 + firstMatch * 2 + gapCost + Math.max(0, span - needle.length) * 2 - boundaryMatches * 5;
}

function preparedTermScore(term, preparedText) {
    const text = preparedText.normalized;
    if (term.length === 0 || text.length === 0)
        return Infinity;

    const textWords = preparedText.words;
    const compact = preparedText.compact;
    const textAcronym = preparedText.acronym;

    if (term === text)
        return 0;

    let bestScore = Infinity;
    for (let index = 0; index < textWords.length; ++index) {
        const word = textWords[index];
        if (word === term)
            bestScore = Math.min(bestScore, 12 + index);
        else if (word.startsWith(term))
            bestScore = Math.min(bestScore, 42 + index * 2 + Math.min(12, word.length - term.length));
    }

    if (text.startsWith(term))
        bestScore = Math.min(bestScore, 28 + Math.min(12, text.length - term.length));

    if (compact === term)
        bestScore = Math.min(bestScore, 18);
    else if (compact.startsWith(term))
        bestScore = Math.min(bestScore, 52 + Math.min(12, compact.length - term.length));

    if (textAcronym === term)
        bestScore = Math.min(bestScore, 24);
    else if (term.length >= 2 && textAcronym.startsWith(term))
        bestScore = Math.min(bestScore, 48 + textAcronym.length - term.length);

    const substringIndex = text.indexOf(term);
    if (substringIndex >= 0)
        bestScore = Math.min(bestScore, 82 + substringIndex);

    const compactSubstringIndex = compact.indexOf(term);
    if (compactSubstringIndex >= 0)
        bestScore = Math.min(bestScore, 96 + compactSubstringIndex);

    // Fuzzy scores start at 132, so they cannot improve a stronger
    // direct, prefix, acronym, or substring match.
    if (bestScore < 132)
        return bestScore;

    const allowedDistance = maximumEditDistance(term.length);
    if (allowedDistance > 0) {
        for (let index = 0; index < textWords.length; ++index) {
            const word = textWords[index];
            if (Math.abs(word.length - term.length) > allowedDistance)
                continue;

            const distance = editDistance(term, word, allowedDistance);
            if (distance <= allowedDistance)
                bestScore = Math.min(bestScore, 132 + distance * 18 + index * 2 + Math.abs(word.length - term.length));
        }
    }

    bestScore = Math.min(bestScore, subsequenceScore(term, text));
    return bestScore;
}

function applicationFields(entry, preparedName) {
    const id = String(entry.id || "").replace(/\.desktop$/i, "");
    const command = listText(entry.command);

    const candidates = [
        { "preparedText": preparedName, "penalty": 0 },
        { "text": entry.genericName, "penalty": 72 },
        { "text": listText(entry.keywords), "penalty": 76 },
        { "text": id, "penalty": 88 },
        { "text": entry.startupClass, "penalty": 92 },
        { "text": entry.comment, "penalty": 112 },
        { "text": listText(entry.categories), "penalty": 124 },
        { "text": command, "penalty": 128 },
        { "text": entry.execString, "penalty": 132 }
    ];
    const fields = [];
    const fieldIndexes = {};

    for (let index = 0; index < candidates.length; ++index) {
        const candidate = candidates[index];
        const candidateText = candidate.preparedText || prepareText(candidate.text);
        if (candidateText.normalized.length === 0)
            continue;

        const fieldKey = "field:" + candidateText.normalized;
        const existingIndex = fieldIndexes[fieldKey];
        if (existingIndex !== undefined) {
            fields[existingIndex].penalty = Math.min(fields[existingIndex].penalty, candidate.penalty);
            continue;
        }

        fieldIndexes[fieldKey] = fields.length;
        fields.push({
            "preparedText": candidateText,
            "penalty": candidate.penalty
        });
    }

    return fields;
}

function createApplicationIndex(applications) {
    return applications.map(entry => {
        const preparedName = prepareText(entry.name);
        return {
            "entry": entry,
            "key": applicationKey(entry),
            "name": preparedName,
            "fields": applicationFields(entry, preparedName),
            "sortName": String(entry.name || ""),
            "sortId": String(entry.id || "")
        };
    });
}

function namePriority(indexedApplication, query) {
    const name = indexedApplication.name.normalized;
    if (name === query.normalized)
        return 0;

    if (name.startsWith(query.normalized))
        return 1;

    const nameWords = indexedApplication.name.words;
    const everyTermStartsAWord = query.terms.every(term => nameWords.some(word => word.startsWith(term)));
    if (everyTermStartsAWord)
        return 1;

    return 2;
}

function matchApplication(indexedApplication, query) {
    if (query.terms.length === 0)
        return null;

    const fields = indexedApplication.fields;
    let totalScore = 0;
    let worstScore = 0;

    for (let termIndex = 0; termIndex < query.terms.length; ++termIndex) {
        const term = query.terms[termIndex];
        let bestTermScore = Infinity;

        for (let fieldIndex = 0; fieldIndex < fields.length; ++fieldIndex) {
            const field = fields[fieldIndex];
            bestTermScore = Math.min(bestTermScore, preparedTermScore(term, field.preparedText) + field.penalty);
        }

        if (!Number.isFinite(bestTermScore))
            return null;

        totalScore += bestTermScore;
        worstScore = Math.max(worstScore, bestTermScore);
    }

    let relevance = totalScore;
    if (query.terms.length > 1) {
        relevance = totalScore / query.terms.length + worstScore * 0.15;
        for (let fieldIndex = 0; fieldIndex < fields.length; ++fieldIndex)
            relevance = Math.min(relevance, preparedTermScore(query.normalized, fields[fieldIndex].preparedText) + fields[fieldIndex].penalty);
    }

    return {
        "priority": namePriority(indexedApplication, query),
        "relevance": relevance
    };
}

function applicationKey(entry) {
    const id = String(entry && entry.id || "").trim();
    if (id.length > 0)
        return "desktop:" + id;

    return "name:" + normalizeText(entry && entry.name || "");
}

function usageData(applicationKey, history, now) {
    if (!history || typeof history !== "object")
        return EMPTY_USAGE_DATA;

    const record = history[applicationKey];
    if (!record || typeof record !== "object")
        return EMPTY_USAGE_DATA;

    const count = Number(record.count);
    const lastLaunched = Number(record.lastLaunched);
    if (!Number.isFinite(count) || count <= 0)
        return EMPTY_USAGE_DATA;

    let frequencyScore = Math.min(18, Math.log(count + 1) / Math.LN2 * 4.5);
    let recencyScore = 0;

    if (Number.isFinite(lastLaunched) && lastLaunched > 0) {
        const age = Math.max(0, now - lastLaunched);
        // Let the launcher adapt when a once-popular app has not been used for
        // months, without immediately discarding the learned preference.
        frequencyScore *= 0.55 + 0.45 * Math.exp(-age / (90 * DAY_IN_MILLISECONDS));
        recencyScore = 10 * Math.exp(-age / (14 * DAY_IN_MILLISECONDS));
    }

    return {
        "boost": Math.min(MAXIMUM_USAGE_BOOST, frequencyScore + recencyScore),
        "count": count,
        "lastLaunched": Number.isFinite(lastLaunched) ? lastLaunched : 0
    };
}

function compareApplications(left, right) {
    const nameComparison = left.sortName.localeCompare(right.sortName);
    if (nameComparison !== 0)
        return nameComparison;

    return left.sortId.localeCompare(right.sortId);
}

function createUsageData(applicationIndex, history, now) {
    const rankingTime = Number.isFinite(now) ? now : Date.now();
    return applicationIndex.map(application => usageData(application.key, history, rankingTime));
}

function rankPreparedApplicationIndex(applicationIndex, query, applicationUsage) {
    const preparedQuery = prepareQuery(query);
    const ranked = [];

    for (let index = 0; index < applicationIndex.length; ++index) {
        const indexedApplication = applicationIndex[index];
        const usage = applicationUsage && applicationUsage[index] || EMPTY_USAGE_DATA;
        const boost = Number.isFinite(usage.boost) ? usage.boost : 0;

        if (preparedQuery.normalized.length === 0) {
            ranked.push({
                "application": indexedApplication,
                "usageCount": Number.isFinite(usage.count) ? usage.count : 0,
                "lastLaunched": Number.isFinite(usage.lastLaunched) ? usage.lastLaunched : 0
            });
            continue;
        }

        const match = matchApplication(indexedApplication, preparedQuery);
        if (!match)
            continue;

        ranked.push({
            "application": indexedApplication,
            "priority": match.priority,
            "score": match.relevance - boost,
            "usage": boost
        });
    }

    ranked.sort((left, right) => {
        if (preparedQuery.normalized.length === 0) {
            if (left.usageCount !== right.usageCount)
                return right.usageCount - left.usageCount;
            if (left.lastLaunched !== right.lastLaunched)
                return right.lastLaunched - left.lastLaunched;
            return compareApplications(left.application, right.application);
        }

        if (left.priority !== right.priority)
            return left.priority - right.priority;
        if (Math.abs(left.score - right.score) > 0.0001)
            return left.score - right.score;
        if (Math.abs(left.usage - right.usage) > 0.0001)
            return right.usage - left.usage;
        return compareApplications(left.application, right.application);
    });

    return ranked.map(match => match.application.entry);
}

function rankApplicationIndex(applicationIndex, query, history, now) {
    return rankPreparedApplicationIndex(applicationIndex, query, createUsageData(applicationIndex, history, now));
}

function rankApplications(applications, query, history, now) {
    return rankApplicationIndex(createApplicationIndex(applications), query, history, now);
}
