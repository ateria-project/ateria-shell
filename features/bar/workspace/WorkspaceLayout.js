.pragma library

// Bar-only geometry and cached layout calculations.
var workspaceWidth = 30;
var windowWidth = 34;
var barHeight = 28;
var activeIndicatorWidth = 32;
var cache = [];

function windowKey(windowId) {
    return "id:" + String(Number(windowId));
}

function build(view, showWorkspaceNumbers, spacingXs, spacingSm) {
    const workspaceView = view || {};
    const showNumbers = Boolean(showWorkspaceNumbers);
    const xs = Number(spacingXs);
    const sm = Number(spacingSm);

    for (const entry of cache) {
        if (entry.view === workspaceView
                && entry.showNumbers === showNumbers
                && entry.spacingXs === xs
                && entry.spacingSm === sm)
            return entry.layout;
    }

    const workspaces = workspaceView.visibleWorkspaces || [];
    const windowsByWorkspace = workspaceView.windowsByWorkspace || {};
    const windowLayoutById = {};
    const workspaceLayouts = [];
    let currentX = 0;

    for (let position = 0; position < workspaces.length; ++position) {
        const workspace = workspaces[position];
        const workspaceWindows = windowsByWorkspace[String(Number(workspace.id))] || [];
        const pillVisible = showNumbers || workspaceWindows.length === 0;
        const contentWidth = (pillVisible ? workspaceWidth : 0)
            + (workspaceWindows.length > 0
                ? (pillVisible ? xs : 0) + workspaceWindows.length * windowWidth
                : 0);

        workspaceLayouts.push({
            "workspace": workspace,
            "x": currentX,
            "width": contentWidth
        });

        for (let windowPosition = 0; windowPosition < workspaceWindows.length; ++windowPosition) {
            const windowData = workspaceWindows[windowPosition];
            windowLayoutById[windowKey(windowData.id)] = {
                "windowData": windowData,
                "x": currentX
                    + (pillVisible ? workspaceWidth + xs : 0)
                    + windowPosition * windowWidth
                    + (windowWidth - activeIndicatorWidth) / 2
            };
        }

        currentX += contentWidth;
        if (position < workspaces.length - 1)
            currentX += sm;
    }

    const activeWindowId = workspaceView.activeWindowId;
    const layout = {
        "totalWidth": currentX,
        "workspaceLayouts": workspaceLayouts,
        "windowLayoutById": windowLayoutById,
        "activeWindowLayout": activeWindowId === null || activeWindowId === undefined
            ? null
            : windowLayoutById[windowKey(activeWindowId)] || null
    };

    cache.push({
        "view": workspaceView,
        "showNumbers": showNumbers,
        "spacingXs": xs,
        "spacingSm": sm,
        "layout": layout
    });
    if (cache.length > 8)
        cache.shift();
    return layout;
}
