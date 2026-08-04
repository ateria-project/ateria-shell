.pragma library

var ICON_EXTENSIONS = ["png", "svg", "xpm"];

function hasOwn(object, key) {
    return Object.prototype.hasOwnProperty.call(object, key);
}

function directSource(icon) {
    const value = String(icon || "").trim();
    return value.startsWith("/") || value.includes("://") ? value : "";
}

function normalizedName(icon) {
    const value = String(icon || "").trim();
    return value.replace(/\.(png|svg|xpm)$/i, "");
}

function cacheKey(icon) {
    const name = normalizedName(icon).toLocaleLowerCase();
    return name.length > 0 ? "icon:" + name : "";
}

function trimTrailingSlashes(path) {
    return String(path || "").replace(/\/+$/, "");
}

function uniquePaths(paths) {
    const seen = {};
    const unique = [];
    for (const value of paths || []) {
        const path = trimTrailingSlashes(value);
        if (path.length === 0 || hasOwn(seen, path))
            continue;

        seen[path] = true;
        unique.push(path);
    }
    return unique;
}

function searchRoots(environment) {
    const env = environment || {};
    const home = trimTrailingSlashes(env.HOME);
    const dataHome = trimTrailingSlashes(env.XDG_DATA_HOME || (home.length > 0 ? home + "/.local/share" : ""));
    const dataRoots = String(env.XDG_DATA_DIRS || "/usr/local/share:/usr/share")
        .split(":")
        .map(trimTrailingSlashes)
        .filter(path => path.length > 0);
    const roots = [];

    if (home.length > 0)
        roots.push(home + "/.icons");
    if (dataHome.length > 0)
        roots.push(dataHome + "/icons");

    for (const root of dataRoots)
        roots.push(root + "/icons");
    for (const root of dataRoots)
        roots.push(root + "/pixmaps");

    // The legacy pixmap directory is a required final fallback.
    roots.push("/usr/share/pixmaps");
    return uniquePaths(roots);
}

function escapeFindPattern(value) {
    let escaped = "";
    for (const character of String(value)) {
        if ("\\*?[]".includes(character))
            escaped += "\\";
        escaped += character;
    }
    return escaped;
}

function uniqueNames(iconNames) {
    const namesByKey = {};
    for (const icon of iconNames || []) {
        const name = normalizedName(icon);
        const key = cacheKey(name);
        if (key.length > 0 && !name.includes("/") && !hasOwn(namesByKey, key))
            namesByKey[key] = name;
    }
    return Object.keys(namesByKey).map(key => namesByKey[key]);
}

function findCommand(iconNames, directories) {
    const names = uniqueNames(iconNames);
    const roots = uniquePaths(directories);
    if (names.length === 0 || roots.length === 0)
        return [];

    // Batch every pending name into one directory walk instead of spawning a process per icon.
    const command = ["find"].concat(roots, ["(", "-type", "f", "-o", "-type", "l", ")", "("]);
    let needsOr = false;
    for (const name of names) {
        for (const extension of ICON_EXTENSIONS) {
            if (needsOr)
                command.push("-o");
            command.push("-iname", escapeFindPattern(name + "." + extension));
            needsOr = true;
        }
    }
    command.push(")", "-print");
    return command;
}

function rootIndex(path, roots) {
    for (let index = 0; index < roots.length; ++index) {
        const root = trimTrailingSlashes(roots[index]);
        if (path === root || path.startsWith(root + "/"))
            return index;
    }
    return roots.length;
}

function candidateScore(path, roots, preferredSize) {
    const lowerPath = path.toLocaleLowerCase();
    const directoryIndex = rootIndex(path, roots);
    const root = directoryIndex < roots.length ? trimTrailingSlashes(roots[directoryIndex]) : "";
    const isUnthemed = root.toLocaleLowerCase().endsWith("/pixmaps");
    // Native theme lookup has already failed. Keep standard fallbacks ahead of unrelated themes.
    const sourceTier = lowerPath.includes("/hicolor/") ? 0 : isUnthemed ? 1 : 2;
    const contextTier = lowerPath.includes("/apps/") ? 0 : 1;
    const extension = lowerPath.match(/\.([^.\/]+)$/);
    const formatTier = extension && extension[1] === "svg" ? 0 : extension && extension[1] === "png" ? 1 : 2;

    const sizePattern = /\/(\d+)x(\d+)(?:@(\d+)x)?\//g;
    let sizeMatch = null;
    let match;
    while ((match = sizePattern.exec(lowerPath)) !== null)
        sizeMatch = match;
    const scale = sizeMatch && sizeMatch[3] ? Number(sizeMatch[3]) : 1;
    const size = sizeMatch ? Number(sizeMatch[1]) * scale : preferredSize;

    return [sourceTier, directoryIndex, contextTier, Math.abs(size - preferredSize), formatTier, lowerPath];
}

function scorePrecedes(left, right) {
    for (let index = 0; index < left.length - 1; ++index) {
        if (left[index] !== right[index])
            return left[index] < right[index];
    }
    return left[left.length - 1] < right[right.length - 1];
}

function selectPaths(output, requestedNames, roots, preferredSize) {
    const requested = {};
    for (const name of uniqueNames(requestedNames))
        requested[cacheKey(name)] = true;

    const paths = {};
    const scores = {};
    for (const line of String(output || "").split("\n")) {
        const path = line.trim();
        const filename = path.match(/\/([^/]+)\.(png|svg|xpm)$/i);
        if (!filename)
            continue;

        const key = cacheKey(filename[1]);
        if (!hasOwn(requested, key))
            continue;

        const score = candidateScore(path, roots, preferredSize);
        if (!hasOwn(paths, key) || scorePrecedes(score, scores[key])) {
            paths[key] = path;
            scores[key] = score;
        }
    }
    return paths;
}
