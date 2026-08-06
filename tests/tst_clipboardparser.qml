import QtQuick
import QtTest
import "../platform/clipboard/ClipboardParser.js" as ClipboardParser

TestCase {
    name: "ClipboardParser"

    function test_parsesCliphistLines() {
        const entries = ClipboardParser.parseList("42\tHello world\n41\tSecond entry\n");

        compare(entries.length, 2);
        compare(entries[0].id, "42");
        compare(entries[0].preview, "Hello world");
        compare(entries[0].rawLine, "42\tHello world");
        compare(entries[1].id, "41");
    }

    function test_preservesWhitespaceInPreview() {
        const entries = ClipboardParser.parseList("7\t  leading and trailing  \n");

        compare(entries.length, 1);
        compare(entries[0].preview, "  leading and trailing  ");
    }

    function test_ignoresMalformedLines() {
        const entries = ClipboardParser.parseList("not an entry\n\tmissing id\n8\tvalid");

        compare(entries.length, 1);
        compare(entries[0].id, "8");
    }
}
