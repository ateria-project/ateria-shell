import Quickshell
pragma Singleton

Singleton {
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 24

    // Shared list grid: compact outer gutter, then a consistent leading
    // icon and label column inside every row.
    readonly property int listOuterInset: spacingMd
    readonly property int listItemInset: spacingLg
    readonly property int listLeadingIconSize: 24
    readonly property int listItemContentGap: spacingMd
    readonly property int listSectionHeaderInset: listItemInset

    readonly property int radiusSm: 8
    readonly property int radiusMd: 12
    readonly property int radiusLg: 20
    readonly property int radiusXl: 24
    readonly property int radiusFull: 999
}
