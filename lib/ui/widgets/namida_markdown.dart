// claude cooked this

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:markdown/markdown.dart' as md;
// ignore: implementation_imports
import 'package:markdown/src/util.dart' show decodeHtmlCharacters;

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

const _kHtmlTag = '__html';
const _kCommitClass = 'gh-commit';
const _kRefClass = 'gh-ref';

class NamidaMarkdown extends StatefulWidget {
  final String? data;
  final NamidaMarkdownDocument? document;
  final bool selectable;
  final bool scrollable;
  final bool smallBodySize;
  final bool smallerNestedBullets;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  const NamidaMarkdown({
    super.key,
    required String this.data,
    required this.selectable,
    this.scrollable = false,
    this.smallBodySize = true,
    this.smallerNestedBullets = false,
    this.padding = const EdgeInsets.all(16.0),
    this.physics,
  }) : document = null;

  const NamidaMarkdown.document({
    super.key,
    required NamidaMarkdownDocument this.document,
    required this.selectable,
    this.scrollable = false,
    this.smallBodySize = true,
    this.smallerNestedBullets = false,
    this.padding = const EdgeInsets.all(16.0),
    this.physics,
  }) : data = null;

  @override
  State<NamidaMarkdown> createState() => _NamidaMarkdownState();
}

class _NamidaMarkdownState extends State<NamidaMarkdown> {
  late NamidaMarkdownDocument _document = _resolveDocument();
  _MdRenderer? _renderer;

  NamidaMarkdownDocument _resolveDocument() => widget.document ?? NamidaMarkdownDocument.parse(widget.data!);

  @override
  void didUpdateWidget(covariant NamidaMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document || widget.data != oldWidget.data) {
      _document = _resolveDocument();
    }
    if (widget.smallBodySize != oldWidget.smallBodySize || widget.smallerNestedBullets != oldWidget.smallerNestedBullets) {
      _renderer = null;
    }
  }

  _MdRenderer _resolveRenderer(ThemeData theme) {
    final current = _renderer;
    if (current != null && identical(current.theme, theme)) return current;
    return _renderer = _MdRenderer(
      theme: theme,
      smallBodySize: widget.smallBodySize,
      smallerNestedBullets: widget.smallerNestedBullets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final renderer = _resolveRenderer(Theme.of(context));
    final blocks = _document._blocks;
    Widget child;
    if (widget.scrollable) {
      child = SuperSmoothListView.builder(
        padding: widget.padding,
        physics: widget.physics,
        itemCount: blocks.length,
        itemBuilder: (context, index) => renderer.buildBlock(blocks[index], renderer.body, first: index == 0),
      );
    } else {
      child = Padding(
        padding: widget.padding,
        child: renderer.buildBlocks(blocks, renderer.body),
      );
    }
    if (widget.selectable) child = SelectionArea(child: child);
    return child;
  }
}

class NamidaMarkdownDocument {
  final List<_MdBlock> _blocks;
  const NamidaMarkdownDocument._(this._blocks);

  static final _blockSyntaxes = <md.BlockSyntax>[
    const _HtmlBlockSyntax(),
    ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
    const md.AlertBlockSyntax(),
  ];

  static final _inlineSyntaxes = <md.InlineSyntax>[
    _InlineHtmlSyntax(),
    _CommitPrefixSyntax(),
    _GithubUrlSyntax(),
    _IssueRefSyntax(),
    md.StrikethroughSyntax(),
    md.EmojiSyntax(),
    md.AutolinkExtensionSyntax(),
  ];

  factory NamidaMarkdownDocument.parse(String data) {
    final document = md.Document(
      blockSyntaxes: _blockSyntaxes,
      inlineSyntaxes: _inlineSyntaxes,
      extensionSet: md.ExtensionSet.none,
      encodeHtml: false,
    );
    final nodes = _MdHtmlNormalizer.normalize(document.parse(data), preformatted: false);
    final builder = _MdBlocksBuilder();
    builder.addNodes(nodes);
    return NamidaMarkdownDocument._(builder.out);
  }

  static Future<NamidaMarkdownDocument> parseAsync(String data) => _parseIsolate.thready(data);

  static NamidaMarkdownDocument _parseIsolate(String data) => NamidaMarkdownDocument.parse(data);
}

// ============================ Syntaxes ============================

class _HtmlBlockSyntax extends md.HtmlBlockSyntax {
  const _HtmlBlockSyntax();

  @override
  md.Node parse(md.BlockParser parser) => md.Element.text(_kHtmlTag, super.parse(parser).textContent);
}

class _InlineHtmlSyntax extends md.InlineHtmlSyntax {
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(_kHtmlTag, match[0]!));
    return true;
  }
}

abstract class _BoundedSyntax extends md.InlineSyntax {
  _BoundedSyntax(super.pattern, {super.startCharacter});

  static const _validPrecedingChars = {0x20, 0x0A, 0x09, 0x28, 0x5B, 0x2C, 0x3B, 0x2A, 0x5F, 0x7E, 0x3E}; // space \n \t ( [ , ; * _ ~ >

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final pos = startMatchPos ?? parser.pos;
    if (pos > 0 && !_validPrecedingChars.contains(parser.charAt(pos - 1))) return false;
    return super.tryMatch(parser, startMatchPos);
  }

  static md.Element ref(String text, String href, String cssClass) {
    return md.Element.text('a', text)
      ..attributes['href'] = href
      ..attributes['class'] = cssClass;
  }
}

/// `abc1234, def5678: message` (changelog style)
class _CommitPrefixSyntax extends md.InlineSyntax {
  _CommitPrefixSyntax() : super(r'^[0-9a-f]{7,40}(?:(?:, ?| & )[0-9a-f]{7,40})*(?=:)');

  static final _partRegex = RegExp(r'[0-9a-f]+|[^0-9a-f]+');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    for (final part in _partRegex.allMatches(match[0]!)) {
      final text = part[0]!;
      if (text.codeUnitAt(0) == 0x2C || text.codeUnitAt(0) == 0x20) {
        parser.addNode(md.Text(text));
      } else {
        parser.addNode(_BoundedSyntax.ref(text.substring(0, 7), '${AppSocial.GITHUB}/commit/$text', _kCommitClass));
      }
    }
    return true;
  }
}

/// github commit/issue/pull urls, displayed as `abc1234` / `#123` / `repo#123`.
class _GithubUrlSyntax extends _BoundedSyntax {
  _GithubUrlSyntax()
    : super(
        r'https://github\.com/([\w.-]+/[\w.-]+)/(?:commit/([0-9a-f]{7,40})|(?:issues|pull|discussions)/(\d+))(?:[?#][^\s<]*[^\s<?!.,:*_~)])?(?![\w/-])',
        startCharacter: 0x68, // h
      );

  static final _ownRepo = AppSocial.GITHUB.substring('https://github.com/'.length).toLowerCase();

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final repo = match[1]!;
    final repoPrefix = repo.toLowerCase() == _ownRepo ? '' : repo.substring(repo.indexOf('/') + 1);
    final commit = match[2];
    final node = commit != null
        ? _BoundedSyntax.ref(repoPrefix.isEmpty ? commit.substring(0, 7) : '$repoPrefix@${commit.substring(0, 7)}', match[0]!, _kCommitClass)
        : _BoundedSyntax.ref('$repoPrefix#${match[3]}', match[0]!, _kRefClass);
    parser.addNode(node);
    return true;
  }
}

/// `#123`
class _IssueRefSyntax extends _BoundedSyntax {
  _IssueRefSyntax() : super(r'#(\d+)(?![\w-])', startCharacter: 0x23);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(_BoundedSyntax.ref(match[0]!, '${AppSocial.GITHUB}/issues/${match[1]}', _kRefClass));
    return true;
  }
}

// ============================ HTML ============================

class _MdHtmlNormalizer {
  static final _tokenRegex = RegExp(
    r'''<!--[\s\S]*?(?:-->|$)|<(/?)([a-zA-Z][a-zA-Z0-9-]*)((?:\s+[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*)\s*(/?)>''',
  );
  static final _attrRegex = RegExp(r'''([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''');
  static final _collapsibleRegex = RegExp(r'[\t\r\n]| {2}');
  static final _whitespaceRegex = RegExp(r'[ \t\r\n]+');

  static const _voidTags = {'br', 'hr', 'img', 'input', 'source', 'wbr', 'meta', 'link', 'col', 'area', 'embed', 'track'};
  static const _selfClosingSiblings = {'li', 'p', 'td', 'th', 'tr', 'dt', 'dd'};

  static String _collapse(String text) => _collapsibleRegex.hasMatch(text) ? text.replaceAll(_whitespaceRegex, ' ') : text;

  static List<md.Node> normalize(List<md.Node> nodes, {required bool preformatted}) {
    final root = <md.Node>[];
    final stack = <md.Element>[];
    var pre = preformatted;

    void add(md.Node node) => (stack.isEmpty ? root : stack.last.children!).add(node);

    void addText(String text, {required bool decode}) {
      if (decode) text = decodeHtmlCharacters(text);
      if (!pre) text = _collapse(text);
      if (text.isNotEmpty) add(md.Text(text));
    }

    void open(String tag, String attributes, bool selfClosing) {
      if (_selfClosingSiblings.contains(tag) && stack.isNotEmpty && stack.last.tag == tag) stack.removeLast();
      final element = md.Element(tag, _voidTags.contains(tag) ? null : <md.Node>[]);
      if (attributes.isNotEmpty) {
        for (final a in _attrRegex.allMatches(attributes)) {
          element.attributes[a[1]!.toLowerCase()] = decodeHtmlCharacters(a[2] ?? a[3] ?? a[4] ?? '');
        }
      }
      add(element);
      if (element.children != null && !selfClosing) {
        stack.add(element);
        if (tag == 'pre') pre = true;
      }
    }

    void close(String tag) {
      final index = stack.lastIndexWhere((e) => e.tag == tag);
      if (index == -1) return;
      stack.removeRange(index, stack.length);
      pre = preformatted || stack.any((e) => e.tag == 'pre');
    }

    for (final node in nodes) {
      if (node is md.Element) {
        if (node.tag == _kHtmlTag) {
          final html = node.textContent;
          var last = 0;
          for (final m in _tokenRegex.allMatches(html)) {
            if (m.start > last) addText(html.substring(last, m.start), decode: true);
            last = m.end;
            final tag = m[2]?.toLowerCase();
            if (tag == null) continue;
            m[1]!.isEmpty ? open(tag, m[3]!, m[4]!.isNotEmpty) : close(tag);
          }
          if (last < html.length) addText(html.substring(last), decode: true);
        } else {
          add(_normalizeElement(node, pre));
        }
      } else if (node is md.Text) {
        final text = pre ? node.text : _collapse(node.text);
        add(identical(text, node.text) ? node : md.Text(text));
      }
    }
    return root;
  }

  static md.Element _normalizeElement(md.Element element, bool preformatted) {
    final children = element.children;
    if (children == null || children.isEmpty) return element;
    final tag = element.tag;
    final normalized = normalize(children, preformatted: preformatted || tag == 'pre' || tag == 'code');
    if (normalized.length == children.length) {
      var same = true;
      for (var i = 0; i < normalized.length; i++) {
        if (!identical(normalized[i], children[i])) {
          same = false;
          break;
        }
      }
      if (same) return element;
    }
    return md.Element(tag, normalized)..attributes.addAll(element.attributes);
  }
}

// ============================ Blocks ============================

sealed class _MdBlock {
  final double gap;
  const _MdBlock(this.gap);
}

class _MdParagraphBlock extends _MdBlock {
  final List<md.Node> inlines;
  final TextAlign align;
  final bool strong;
  const _MdParagraphBlock(this.inlines, this.align, {this.strong = false}) : super(8.0);
}

class _MdHeadingBlock extends _MdBlock {
  final int level;
  final List<md.Node> inlines;
  final TextAlign align;
  final String? link;
  const _MdHeadingBlock(this.level, this.inlines, this.align, this.link, super.gap);
}

enum _MdMarkerType { bullet, ordered, taskDone, taskPending }

class _MdListItemBlock extends _MdBlock {
  final List<_MdBlock> content;
  final int depth;
  final double indentEm;
  final double markerEm;
  final _MdMarkerType? marker;
  final String? markerText;
  final bool commit;
  final bool parent;
  const _MdListItemBlock({
    required double gap,
    required this.content,
    required this.depth,
    required this.indentEm,
    required this.markerEm,
    required this.marker,
    required this.markerText,
    required this.commit,
    required this.parent,
  }) : super(gap);
}

class _MdQuoteBlock extends _MdBlock {
  final List<_MdBlock> content;
  final _MdAlert? alert;
  final String? alertTitle;
  const _MdQuoteBlock(this.content, this.alert, this.alertTitle) : super(10.0);
}

enum _MdAlert { note, tip, important, warning, caution }

class _MdCodeBlock extends _MdBlock {
  final String code;
  const _MdCodeBlock(this.code) : super(10.0);
}

class _MdRuleBlock extends _MdBlock {
  const _MdRuleBlock() : super(10.0);
}

class _MdTableCell {
  final List<_MdBlock> content;
  final bool header;
  const _MdTableCell(this.content, this.header);
}

class _MdTableBlock extends _MdBlock {
  final List<List<_MdTableCell>> rows;
  final List<bool> headerRows;
  final int columns;
  final bool nested;
  const _MdTableBlock(this.rows, this.headerRows, this.columns, this.nested) : super(10.0);
}

class _MdDetailsBlock extends _MdBlock {
  final List<_MdBlock> summary;
  final List<_MdBlock> content;
  final bool open;
  const _MdDetailsBlock(this.summary, this.content, this.open) : super(10.0);
}

class _MdBlocksBuilder {
  final bool inTable;
  final double indentEm;
  final int depth;
  final bool commit;
  _MdBlocksBuilder({this.inTable = false, this.indentEm = 0.0, this.depth = -1, this.commit = false});

  final out = <_MdBlock>[];

  static const _blockTags = {
    'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'blockquote', 'pre', 'hr', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th', //
    'div', 'details', 'summary', 'section', 'article', 'header', 'footer', 'nav', 'aside', 'main', 'figure', 'figcaption', 'center', 'dl', 'dt', 'dd',
  };

  static const _bulletEm = 1.25;
  static const _taskEm = 1.6;
  static final _versionRegex = RegExp(r'^v\d+(?:\.\d+)+\S*$');
  static final _textAlignRegex = RegExp(r'text-align\s*:\s*(\w+)');

  static List<_MdBlock> buildNested(List<md.Node> nodes, {bool inTable = false, bool commit = false, TextAlign? align}) {
    final builder = _MdBlocksBuilder(inTable: inTable, commit: commit);
    builder.addNodes(nodes, align: align);
    return builder.out;
  }

  void _add(_MdBlock block) {
    if (indentEm > 0) {
      out.add(
        _MdListItemBlock(
          gap: block.gap,
          content: [block],
          depth: depth,
          indentEm: indentEm,
          markerEm: 0.0,
          marker: null,
          markerText: null,
          commit: commit,
          parent: false,
        ),
      );
    } else {
      out.add(block);
    }
  }

  void addNodes(List<md.Node> nodes, {TextAlign? align}) {
    List<md.Node>? run;
    for (final node in nodes) {
      if (node is md.Element && _blockTags.contains(node.tag)) {
        if (run != null) {
          _addParagraph(run, align ?? TextAlign.start);
          run = null;
        }
        _addElement(node, align);
      } else {
        (run ??= []).add(node);
      }
    }
    if (run != null) _addParagraph(run, align ?? TextAlign.start);
  }

  void _addParagraph(List<md.Node> nodes, TextAlign align, {bool strong = false}) {
    final inlines = _trimInlines(nodes);
    if (inlines.isEmpty) return;
    _add(_MdParagraphBlock(inlines, align, strong: strong));
  }

  void _addElement(md.Element element, TextAlign? parentAlign) {
    final children = element.children ?? const <md.Node>[];
    final align = _alignOf(element) ?? parentAlign;
    switch (element.tag) {
      case 'p':
        _addParagraph(children, align ?? TextAlign.start);
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final inlines = _trimInlines(children);
        if (inlines.isEmpty) return;
        final level = element.tag.codeUnitAt(1) - 0x30;
        String? link;
        if (level == 1) {
          final version = element.textContent.replaceAll(' ', '');
          if (_versionRegex.hasMatch(version)) link = '${AppSocial.GITHUB}/releases/tag/$version';
        }
        _add(_MdHeadingBlock(level, inlines, align ?? (level == 1 ? TextAlign.center : TextAlign.start), link, const [20.0, 16.0, 12.0, 10.0, 10.0, 10.0][level - 1]));
      case 'ul' || 'ol':
        _addList(element);
      case 'li':
        _addList(md.Element('ul', [element]));
      case 'blockquote':
        _add(_MdQuoteBlock(buildNested(children, inTable: inTable), null, null));
      case 'div' when element.attributes['class']?.startsWith('markdown-alert ') ?? false:
        _addAlert(element, children);
      case 'pre':
        var code = element.textContent;
        if (code.endsWith('\n')) code = code.substring(0, code.length - 1);
        _add(_MdCodeBlock(code));
      case 'hr':
        _add(const _MdRuleBlock());
      case 'table':
        _addTable(element);
      case 'details':
        _addDetails(children, element.attributes.containsKey('open'));
      case 'summary' || 'dt':
        _addParagraph(children, align ?? TextAlign.start, strong: true);
      case 'dd':
        final builder = _MdBlocksBuilder(inTable: inTable, indentEm: indentEm + _bulletEm, depth: depth, commit: commit);
        builder.addNodes(children, align: align);
        out.addAll(builder.out);
      default:
        addNodes(children, align: align);
    }
  }

  void _addAlert(md.Element element, List<md.Node> children) {
    final type = element.attributes['class']!.substring('markdown-alert markdown-alert-'.length);
    final alert = _MdAlert.values.firstWhereEff((e) => e.name == type) ?? _MdAlert.note;
    String? title;
    final content = <md.Node>[];
    for (final c in children) {
      if (title == null && c is md.Element && c.attributes['class'] == 'markdown-alert-title') {
        title = c.textContent.trim();
      } else {
        content.add(c);
      }
    }
    _add(_MdQuoteBlock(buildNested(content, inTable: inTable), alert, title));
  }

  void _addDetails(List<md.Node> children, bool open) {
    List<_MdBlock>? summary;
    final content = <md.Node>[];
    for (final c in children) {
      if (summary == null && c is md.Element && c.tag == 'summary') {
        summary = buildNested(c.children ?? const []);
      } else {
        content.add(c);
      }
    }
    _add(
      _MdDetailsBlock(
        summary ??
            [
              _MdParagraphBlock([md.Text('Details')], TextAlign.start),
            ],
        buildNested(content, inTable: inTable),
        open,
      ),
    );
  }

  void _addTable(md.Element table) {
    final rows = <List<_MdTableCell>>[];
    final headerRows = <bool>[];
    var columns = 0;

    void collect(md.Element element, bool head) {
      for (final child in element.children ?? const <md.Node>[]) {
        if (child is! md.Element) continue;
        switch (child.tag) {
          case 'tr':
            final cells = <_MdTableCell>[];
            var allHeaders = true;
            for (final cell in child.children ?? const <md.Node>[]) {
              if (cell is! md.Element || (cell.tag != 'td' && cell.tag != 'th')) continue;
              final isHeader = head || cell.tag == 'th';
              if (!isHeader) allHeaders = false;
              cells.add(_MdTableCell(buildNested(cell.children ?? const [], inTable: true, align: _alignOf(cell)), isHeader));
            }
            if (cells.isEmpty) continue;
            rows.add(cells);
            headerRows.add(allHeaders);
            columns = math.max(columns, cells.length);
          case 'thead':
            collect(child, true);
          case 'tbody' || 'tfoot':
            collect(child, head);
        }
      }
    }

    collect(table, false);
    if (rows.isEmpty) return;
    _add(_MdTableBlock(rows, headerRows, columns, inTable));
  }

  void _addList(md.Element list) {
    final ordered = list.tag == 'ol';
    var number = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    final items = <md.Element>[];
    var loose = false;
    var hasTasks = false;
    for (final c in list.children ?? const <md.Node>[]) {
      if (c is md.Element && c.tag == 'li') {
        items.add(c);
        final first = c.children?.firstOrNull;
        if (first is md.Element) {
          if (first.tag == 'p') loose = true;
          if (_checkboxOf(first) != null) hasTasks = true;
        }
      }
    }
    if (items.isEmpty) return;

    final childDepth = depth + 1;
    final markerEm = hasTasks
        ? _taskEm
        : ordered
        ? 0.62 * '${number + items.length - 1}.'.length + 0.7
        : _bulletEm;

    for (var i = 0; i < items.length; i++) {
      var children = items[i].children ?? const <md.Node>[];
      bool? checked;
      (children, checked) = _extractCheckbox(children);
      final itemCommit = commit || _startsWithCommit(children);
      final splitIndex = children.indexWhere((c) => c is md.Element && (c.tag == 'ul' || c.tag == 'ol'));
      final head = splitIndex == -1 ? children : children.sublist(0, splitIndex);

      final _MdMarkerType marker;
      if (checked != null) {
        marker = checked ? _MdMarkerType.taskDone : _MdMarkerType.taskPending;
      } else {
        marker = ordered ? _MdMarkerType.ordered : _MdMarkerType.bullet;
      }

      out.add(
        _MdListItemBlock(
          gap: i == 0
              ? (childDepth == 0 ? 6.0 : 2.0)
              : loose
              ? 8.0
              : (childDepth == 0 ? 5.0 : 3.0),
          content: buildNested(head, inTable: inTable, commit: itemCommit),
          depth: childDepth,
          indentEm: indentEm,
          markerEm: markerEm,
          marker: marker,
          markerText: ordered ? '${number++}.' : null,
          commit: itemCommit,
          parent: splitIndex != -1,
        ),
      );

      if (splitIndex != -1) {
        final builder = _MdBlocksBuilder(inTable: inTable, indentEm: indentEm + markerEm, depth: childDepth, commit: itemCommit);
        builder.addNodes(children.sublist(splitIndex));
        out.addAll(builder.out);
      }
    }
  }

  static bool? _checkboxOf(md.Element element) {
    if (element.tag == 'input' && element.attributes['type'] == 'checkbox') return element.attributes.containsKey('checked');
    if (element.tag == 'p') {
      final first = element.children?.firstOrNull;
      if (first is md.Element && first.tag == 'input' && first.attributes['type'] == 'checkbox') return first.attributes.containsKey('checked');
    }
    return null;
  }

  static (List<md.Node>, bool?) _extractCheckbox(List<md.Node> children) {
    final first = children.firstOrNull;
    if (first is! md.Element) return (children, null);
    final checked = _checkboxOf(first);
    if (checked == null) return (children, null);
    if (first.tag == 'input') return (children.sublist(1), checked);
    final paragraph = md.Element('p', first.children!.sublist(1))..attributes.addAll(first.attributes);
    return ([paragraph, ...children.skip(1)], checked);
  }

  static bool _startsWithCommit(List<md.Node> children) {
    var first = children.firstOrNull;
    if (first is md.Element && first.tag == 'p') first = first.children?.firstOrNull;
    return first is md.Element && first.tag == 'a' && first.attributes['class'] == _kCommitClass;
  }

  static TextAlign? _alignOf(md.Element element) {
    final attrs = element.attributes;
    if (attrs.isEmpty) return null;
    final value = attrs['align'] ?? (attrs['style'] == null ? null : _textAlignRegex.firstMatch(attrs['style']!)?[1]);
    return switch (value?.toLowerCase()) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'left' => TextAlign.left,
      'justify' => TextAlign.justify,
      _ => null,
    };
  }

  static List<md.Node> _trimInlines(List<md.Node> nodes) {
    var start = 0;
    var end = nodes.length;
    while (start < end && _isBlank(nodes[start])) {
      start++;
    }
    while (end > start && _isBlank(nodes[end - 1])) {
      end--;
    }
    if (start == end) return const [];
    final result = start == 0 && end == nodes.length ? List.of(nodes) : nodes.sublist(start, end);
    final first = result.first;
    if (first is md.Text) {
      final t = first.text.trimLeft();
      if (t.length != first.text.length) result[0] = md.Text(t);
    }
    final last = result.last;
    if (last is md.Text) {
      final t = last.text.trimRight();
      if (t.length != last.text.length) result[result.length - 1] = md.Text(t);
    }
    return result;
  }

  static bool _isBlank(md.Node node) => node is md.Text && node.text.trim().isEmpty;
}

// ============================ Rendering ============================

class _MdRenderer {
  final ThemeData theme;
  final bool smallerNestedBullets;

  final TextStyle body;
  final double em;
  final TextStyle _bodyNested;
  final TextStyle _emphasis;
  final TextStyle _emphasisNested;
  final TextStyle _detail;
  final TextStyle _detailNested;
  final TextStyle _markerStyle;
  final List<TextStyle> _headingStyles;
  final Color linkColor;
  final Color codeBackground;
  final Color borderColor;
  final Color surfaceColor;

  static const _monoFallback = ['Cascadia Mono', 'Consolas', 'Menlo', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New', 'sans-serif', 'Roboto'];

  factory _MdRenderer({
    required ThemeData theme,
    required bool smallBodySize,
    required bool smallerNestedBullets,
  }) {
    final tt = theme.textTheme;
    final small = tt.displaySmall!;
    final medium = tt.displayMedium!;
    final body = smallBodySize ? small : medium.copyWith(fontSize: 14.0);
    return _MdRenderer._(
      theme: theme,
      smallerNestedBullets: smallerNestedBullets,
      body: body,
      em: body.fontSize!,
      medium: medium,
      small: small,
      large: tt.displayLarge!,
    );
  }

  _MdRenderer._({
    required this.theme,
    required this.smallerNestedBullets,
    required this.body,
    required this.em,
    required TextStyle medium,
    required TextStyle small,
    required TextStyle large,
  }) : _bodyNested = smallerNestedBullets ? body.copyWith(fontSize: em - 1.5) : body,
       _emphasis = medium.copyWith(fontSize: em),
       _emphasisNested = medium.copyWith(fontSize: smallerNestedBullets ? em - 1.5 : em),
       _detail = small.copyWith(fontSize: em),
       _detailNested = small.copyWith(fontSize: smallerNestedBullets ? em - 1.5 : em),
       _markerStyle = medium.copyWith(fontSize: em, color: medium.color?.withOpacityExt(0.6)),
       _headingStyles = [
         medium,
         large,
         medium,
         medium.copyWith(fontSize: 14.0),
         small.copyWith(fontWeight: FontWeight.w600),
         small.copyWith(fontWeight: FontWeight.w600, color: small.color?.withOpacityExt(0.8)),
       ],
       linkColor = theme.colorScheme.secondary,
       codeBackground = theme.colorScheme.onSurface.withOpacityExt(0.08),
       borderColor = theme.colorScheme.onSurface.withOpacityExt(0.12),
       surfaceColor = theme.colorScheme.onSurface.withOpacityExt(0.04);

  TextStyle inlineCodeStyle(double fontSize) => TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: _monoFallback,
    fontSize: fontSize * 0.9,
    backgroundColor: codeBackground,
  );

  Widget buildBlocks(List<_MdBlock> blocks, TextStyle style) {
    if (blocks.isEmpty) return const SizedBox();
    if (blocks.length == 1) return buildBlock(blocks[0], style, first: true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) buildBlock(blocks[i], style, first: i == 0),
      ],
    );
  }

  Widget buildBlock(_MdBlock block, TextStyle style, {required bool first}) {
    final child = switch (block) {
      _MdParagraphBlock() => _MdParagraph(
        renderer: this,
        inlines: block.inlines,
        style: block.strong ? style.copyWith(fontWeight: _MdSpanBuilder.bolder(style.fontWeight)) : style,
        align: block.align,
      ),
      _MdHeadingBlock() => _heading(block),
      _MdListItemBlock() => _listItem(block),
      _MdQuoteBlock() => _quote(block, style),
      _MdCodeBlock() => _code(block),
      _MdRuleBlock() => Divider(height: 1.0, thickness: 1.0, color: borderColor),
      _MdTableBlock() => _table(block, style),
      _MdDetailsBlock() => _MdDetails(renderer: this, block: block, style: style),
    };
    if (first || block.gap == 0) return child;
    return Padding(
      padding: EdgeInsets.only(top: block.gap),
      child: child,
    );
  }

  Widget _heading(_MdHeadingBlock block) {
    final text = _MdParagraph(
      renderer: this,
      inlines: block.inlines,
      style: _headingStyles[block.level - 1],
      align: block.align,
    );
    if (block.level != 1) return text;
    final link = block.link;
    return Center(
      child: NamidaInkWell(
        onTap: link == null ? null : () => NamidaLinkUtils.openLink(link),
        bgColor: theme.cardTheme.color?.withOpacityExt(0.8),
        borderRadius: 18.0,
        decoration: BoxDecoration(
          border: Border.all(
            width: 1.5,
            color: theme.colorScheme.primary.withOpacityExt(0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: text,
      ),
    );
  }

  Widget _listItem(_MdListItemBlock block) {
    final nested = block.depth > 0;
    final style = block.commit
        ? (nested ? _detailNested : _detail)
        : block.parent
        ? (nested ? _emphasisNested : _emphasis)
        : (nested ? _bodyNested : body);
    Widget child = buildBlocks(block.content, style);
    final marker = block.marker;
    if (marker != null) {
      child = Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: block.markerEm * em,
            child: _marker(marker, block, style),
          ),
          Expanded(child: child),
        ],
      );
    }
    if (block.indentEm > 0) {
      child = Padding(
        padding: EdgeInsetsDirectional.only(start: block.indentEm * em),
        child: child,
      );
    }
    return child;
  }

  Widget _marker(_MdMarkerType marker, _MdListItemBlock block, TextStyle style) {
    switch (marker) {
      case _MdMarkerType.bullet:
        return _MdBullet(
          fontSize: style.fontSize ?? em,
          color: _markerStyle.color ?? theme.colorScheme.onSurface,
          shape: _MdBulletShape.values[block.depth % _MdBulletShape.values.length],
        );
      case _MdMarkerType.ordered:
        return Padding(
          padding: EdgeInsetsDirectional.only(end: em * 0.4),
          child: Text(
            block.markerText!,
            textAlign: TextAlign.end,
            style: _markerStyle.copyWith(fontSize: style.fontSize, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        );
      case _MdMarkerType.taskDone || _MdMarkerType.taskPending:
        final done = marker == _MdMarkerType.taskDone;
        final icon = done ? Broken.tick_square : Broken.stop;
        return Text(
          String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: (style.fontSize ?? em) + 2.0,
            color: done ? theme.colorScheme.primary : _markerStyle.color,
          ),
        );
    }
  }

  Widget _quote(_MdQuoteBlock block, TextStyle style) {
    final alert = block.alert;
    final color = alert == null ? theme.colorScheme.primary.withOpacityExt(0.5) : _alertColor(alert);
    final content = buildBlocks(block.content, style);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: alert == null ? surfaceColor : color.withOpacityExt(0.06),
        borderRadius: const BorderRadius.all(Radius.circular(6.0)),
        border: BorderDirectional(
          start: BorderSide(color: color, width: 3.0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 10.0, 8.0),
        child: alert == null
            ? content
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        _alertIcon(alert),
                        size: em + 3.0,
                        color: color,
                      ),
                      const SizedBox(width: 6.0),
                      Flexible(
                        child: Text(
                          block.alertTitle ?? alert.name,
                          style: _emphasis.copyWith(color: color),
                        ),
                      ),
                    ],
                  ),
                  if (block.content.isNotEmpty) const SizedBox(height: 6.0),
                  if (block.content.isNotEmpty) content,
                ],
              ),
      ),
    );
  }

  Color _alertColor(_MdAlert alert) => switch (alert) {
    _MdAlert.note => const Color(0xFF4493F8),
    _MdAlert.tip => const Color(0xFF3FB950),
    _MdAlert.important => const Color(0xFFAB7DF8),
    _MdAlert.warning => const Color(0xFFD29922),
    _MdAlert.caution => const Color(0xFFF85149),
  };

  IconData _alertIcon(_MdAlert alert) => switch (alert) {
    _MdAlert.note => Broken.info_circle,
    _MdAlert.tip => Broken.lamp_charge,
    _MdAlert.important => Broken.message_question,
    _MdAlert.warning => Broken.warning_2,
    _MdAlert.caution => Broken.danger,
  };

  Widget _code(_MdCodeBlock block) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: codeBackground,
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Text(
          block.code,
          softWrap: false,
          style: body.copyWith(
            fontFamily: 'monospace',
            fontFamilyFallback: _monoFallback,
            fontWeight: FontWeight.w400,
            fontSize: em - 0.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _table(_MdTableBlock block, TextStyle style) {
    const radius = BorderRadius.all(Radius.circular(8.0));
    final headerStyle = style.copyWith(fontWeight: _MdSpanBuilder.bolder(style.fontWeight));
    final headerDecoration = BoxDecoration(color: surfaceColor);
    const cellPadding = EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0);
    final table = ClipRRect(
      borderRadius: radius,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder.all(color: borderColor, borderRadius: radius),
        children: [
          for (var r = 0; r < block.rows.length; r++)
            TableRow(
              decoration: block.headerRows[r] ? headerDecoration : null,
              children: [
                for (var c = 0; c < block.columns; c++)
                  if (c < block.rows[r].length)
                    Padding(
                      padding: cellPadding,
                      child: buildBlocks(block.rows[r][c].content, block.rows[r][c].header ? headerStyle : style),
                    )
                  else
                    const SizedBox(),
              ],
            ),
        ],
      ),
    );
    if (block.nested) return table;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _TableWidthFit(
          maxWidth: constraints.maxWidth,
          child: table,
        ),
      ),
    );
  }
}

class _MdSpanBuilder {
  final _MdRenderer renderer;
  final List<GestureRecognizer> recognizers;
  const _MdSpanBuilder(this.renderer, this.recognizers);

  static FontWeight bolder(FontWeight? weight) {
    final value = (weight ?? FontWeight.w400).value;
    return FontWeight(math.min(value + (value < 600 ? 300 : 200), 900));
  }

  InlineSpan build(List<md.Node> nodes, TextStyle style) {
    return TextSpan(
      style: style,
      children: _spans(nodes, style.fontSize ?? renderer.em, style.fontWeight ?? FontWeight.w400, null),
    );
  }

  List<InlineSpan> _spans(List<md.Node>? nodes, double fontSize, FontWeight weight, GestureRecognizer? link) {
    final out = <InlineSpan>[];
    if (nodes == null) return out;
    for (final node in nodes) {
      if (node is md.Text) {
        out.add(TextSpan(text: node.text, recognizer: link));
        continue;
      }
      if (node is! md.Element) continue;
      final children = node.children;
      switch (node.tag) {
        case 'br':
          out.add(TextSpan(text: '\n', recognizer: link));
        case 'strong' || 'b':
          final bold = bolder(weight);
          out.add(
            TextSpan(
              style: TextStyle(fontWeight: bold),
              children: _spans(children, fontSize, bold, link),
            ),
          );
        case 'em' || 'i' || 'cite' || 'dfn' || 'var':
          out.add(
            TextSpan(
              style: const TextStyle(fontStyle: FontStyle.italic),
              children: _spans(children, fontSize, weight, link),
            ),
          );
        case 'del' || 's' || 'strike':
          out.add(
            TextSpan(
              style: const TextStyle(decoration: TextDecoration.lineThrough),
              children: _spans(children, fontSize, weight, link),
            ),
          );
        case 'u' || 'ins':
          out.add(
            TextSpan(
              style: const TextStyle(decoration: TextDecoration.underline),
              children: _spans(children, fontSize, weight, link),
            ),
          );
        case 'mark':
          out.add(
            TextSpan(
              style: TextStyle(backgroundColor: renderer.theme.colorScheme.primary.withOpacityExt(0.25)),
              children: _spans(children, fontSize, weight, link),
            ),
          );
        case 'code' || 'kbd' || 'samp' || 'tt':
          out.add(TextSpan(text: node.textContent, style: renderer.inlineCodeStyle(fontSize), recognizer: link));
        case 'sub' || 'sup' || 'small':
          final size = fontSize * 0.8;
          out.add(
            TextSpan(
              style: TextStyle(fontSize: size),
              children: _spans(children, size, weight, link),
            ),
          );
        case 'a':
          final href = node.attributes['href'];
          var recognizer = link;
          if (href != null && href.isNotEmpty && !href.startsWith('#')) {
            recognizer = TapGestureRecognizer()..onTap = () => NamidaLinkUtils.openLink(href);
            recognizers.add(recognizer);
          }
          final cssClass = node.attributes['class'];
          final isRef = cssClass == _kCommitClass || cssClass == _kRefClass;
          final refWeight = isRef ? FontWeight(math.max(weight.value, 600)) : weight;
          out.add(
            TextSpan(
              style: TextStyle(color: renderer.linkColor, fontWeight: refWeight),
              children: _spans(children, fontSize, refWeight, recognizer),
            ),
          );
        case 'img':
          final src = node.attributes['src'];
          if (src == null || src.isEmpty) continue;
          out.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _MdImage(
                src: src,
                alt: node.attributes['alt'] ?? node.attributes['title'],
                width: double.tryParse(node.attributes['width'] ?? ''),
                height: double.tryParse(node.attributes['height'] ?? ''),
                style: TextStyle(fontSize: fontSize),
              ),
            ),
          );
        case 'input':
          continue;
        default:
          out.addAll(_spans(children, fontSize, weight, link));
      }
    }
    return out;
  }
}

class _MdParagraph extends StatefulWidget {
  final _MdRenderer renderer;
  final List<md.Node> inlines;
  final TextStyle style;
  final TextAlign align;

  const _MdParagraph({
    required this.renderer,
    required this.inlines,
    required this.style,
    required this.align,
  });

  @override
  State<_MdParagraph> createState() => _MdParagraphState();
}

class _MdParagraphState extends State<_MdParagraph> {
  final _recognizers = <GestureRecognizer>[];
  late InlineSpan _span = _buildSpan();

  InlineSpan _buildSpan() => _MdSpanBuilder(widget.renderer, _recognizers).build(widget.inlines, widget.style);

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void didUpdateWidget(covariant _MdParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inlines != oldWidget.inlines || widget.style != oldWidget.style || widget.renderer != oldWidget.renderer) {
      _disposeRecognizers();
      _span = _buildSpan();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      _span,
      textAlign: widget.align,
    );
  }
}

class _MdImage extends StatelessWidget {
  final String src;
  final String? alt;
  final double? width;
  final double? height;
  final TextStyle style;

  const _MdImage({
    required this.src,
    required this.alt,
    required this.width,
    required this.height,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(6.0)),
        child: Image.network(
          src,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Text(
            alt ?? src,
            style: style,
          ),
        ),
      ),
    );
  }
}

class _MdDetails extends StatefulWidget {
  final _MdRenderer renderer;
  final _MdDetailsBlock block;
  final TextStyle style;

  const _MdDetails({
    required this.renderer,
    required this.block,
    required this.style,
  });

  @override
  State<_MdDetails> createState() => _MdDetailsState();
}

class _MdDetailsState extends State<_MdDetails> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.block.open ? 1.0 : 0.0,
  )..addStatusListener(_onStatusChanged);
  late final _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final _turns = Tween<double>(begin: 0.0, end: 0.25).animate(_animation);

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed || status == AnimationStatus.forward) setState(() {});
  }

  void _toggle() {
    _controller.isForwardOrCompleted ? _controller.reverse() : _controller.forward();
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderer = widget.renderer;
    final block = widget.block;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NamidaInkWell(
          onTap: _toggle,
          bgColor: renderer.surfaceColor,
          borderRadius: 10.0,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Row(
            children: [
              RotationTransition(
                turns: _turns,
                child: Icon(
                  Broken.arrow_right_3,
                  size: renderer.em + 3.0,
                  color: renderer._markerStyle.color,
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: renderer.buildBlocks(block.summary, renderer._emphasis),
              ),
            ],
          ),
        ),
        SizeTransition(
          sizeFactor: _animation,
          alignment: AlignmentDirectional.topStart,
          child: _controller.isDismissed
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(top: 10.0, start: 4.0),
                  child: renderer.buildBlocks(block.content, widget.style),
                ),
        ),
      ],
    );
  }
}

enum _MdBulletShape { disc, circle, square }

class _MdBullet extends LeafRenderObjectWidget {
  final double fontSize;
  final Color color;
  final _MdBulletShape shape;

  const _MdBullet({
    required this.fontSize,
    required this.color,
    required this.shape,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMdBullet(
    MediaQuery.textScalerOf(context).scale(fontSize),
    color,
    shape,
    Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, _RenderMdBullet renderObject) {
    renderObject
      ..fontSize = MediaQuery.textScalerOf(context).scale(fontSize)
      ..color = color
      ..shape = shape
      ..textDirection = Directionality.of(context);
  }
}

/// Paints a list bullet centered on the x-height, reporting a baseline so it aligns with the item's first line.
class _RenderMdBullet extends RenderBox {
  _RenderMdBullet(this._fontSize, Color color, this._shape, this._textDirection) : _paint = Paint()..color = color;

  static const _xCenterEm = 0.28;
  static const _diameterEm = 0.34;

  final Paint _paint;

  double _fontSize;
  set fontSize(double value) {
    if (value == _fontSize) return;
    _fontSize = value;
    markNeedsLayout();
  }

  set color(Color value) {
    if (value == _paint.color) return;
    _paint.color = value;
    markNeedsPaint();
  }

  _MdBulletShape _shape;
  set shape(_MdBulletShape value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsPaint();
  }

  double get _diameter => _fontSize * _diameterEm;
  double get _baseline => _fontSize * _xCenterEm + _diameter / 2;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(Size(_diameter, _baseline));

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) => _baseline;

  @override
  double computeMinIntrinsicWidth(double height) => _diameter;

  @override
  double computeMaxIntrinsicWidth(double height) => _diameter;

  @override
  double computeMinIntrinsicHeight(double width) => _baseline;

  @override
  double computeMaxIntrinsicHeight(double width) => _baseline;

  @override
  void paint(PaintingContext context, Offset offset) {
    final d = _diameter;
    final r = d / 2;
    final inset = _fontSize * 0.1 + r;
    final dx = _textDirection == TextDirection.ltr ? inset : size.width - inset;
    final center = offset + Offset(dx, r);
    final canvas = context.canvas;
    switch (_shape) {
      case _MdBulletShape.disc:
        canvas.drawCircle(center, r, _paint..style = PaintingStyle.fill);
      case _MdBulletShape.circle:
        final stroke = d * 0.24;
        canvas.drawCircle(
          center,
          r - stroke / 2,
          _paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
        );
      case _MdBulletShape.square:
        canvas.drawRect(Rect.fromCenter(center: center, width: d * 0.85, height: d * 0.85), _paint..style = PaintingStyle.fill);
    }
  }
}

/// Lays out a table at its natural width, capped to [maxWidth] unless even its minimum width exceeds it (then scrolls).
class _TableWidthFit extends SingleChildRenderObjectWidget {
  final double maxWidth;

  const _TableWidthFit({
    required this.maxWidth,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTableWidthFit(maxWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderTableWidthFit renderObject) {
    renderObject.maxWidth = maxWidth;
  }
}

class _RenderTableWidthFit extends RenderProxyBox {
  _RenderTableWidthFit(this._maxWidth);

  double _maxWidth;
  set maxWidth(double value) {
    if (value == _maxWidth) return;
    _maxWidth = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(RenderBox child, BoxConstraints constraints) {
    final width = math.max(_maxWidth, child.getMinIntrinsicWidth(double.infinity));
    return BoxConstraints(maxWidth: width, minHeight: constraints.minHeight, maxHeight: constraints.maxHeight);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(child.getDryLayout(_childConstraints(child, constraints)));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(child, constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}
