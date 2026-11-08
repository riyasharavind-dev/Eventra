import 'package:flutter/material.dart';

class LegalDocumentContent extends StatelessWidget {
  const LegalDocumentContent({super.key, required this.text});

  final String text;

  List<InlineSpan> _inline(String text) {
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in RegExp(r'\*\*(.+?)\*\*').allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final paragraph = <String>[];

    void addText(String value, {int heading = 0, bool bullet = false}) {
      final style = TextStyle(
        fontSize: heading == 0
            ? 15
            : heading == 1
            ? 23
            : 18,
        height: 1.65,
        color: const Color(0xFF25252B),
        fontWeight: heading == 0 ? FontWeight.w400 : FontWeight.w700,
      );
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: 12, top: heading == 0 ? 0 : 8),
          child: SelectableText.rich(
            TextSpan(
              children: [
                if (bullet) const TextSpan(text: '• '),
                ..._inline(value),
              ],
            ),
            style: style,
          ),
        ),
      );
    }

    void flush() {
      if (paragraph.isEmpty) return;
      addText(paragraph.join(' '));
      paragraph.clear();
    }

    for (final line in text.replaceAll('\r\n', '\n').split('\n')) {
      final value = line.trim();
      final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(value);
      final bullet = RegExp(r'^[-*]\s+(.+)$').firstMatch(value);
      if (value.isEmpty) {
        flush();
      } else if (heading != null) {
        flush();
        addText(heading.group(2)!, heading: heading.group(1)!.length);
      } else if (bullet != null) {
        flush();
        addText(bullet.group(1)!, bullet: true);
      } else {
        paragraph.add(value);
      }
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
