"""Mark every declaration of a stylesheet `!important`.

userContent.css is a *user* origin sheet: its normal declarations lose to the
page's own normal ones whatever the specificity, so the Catppuccin styles
(written for Stylus, which injects them as author CSS) only half applied.
User `!important` wins over the page instead. Not inside @keyframes and
@font-face: `!important` there makes the declaration invalid.
"""

import sys

import tinycss2

GROUPING = {"-moz-document", "media", "supports", "layer", "container"}


def declarations(content):
    out = []
    for node in tinycss2.parse_blocks_contents(content):
        if node.type == "declaration":
            node.important = True
        elif node.type == "qualified-rule":
            node.content = declarations(node.content)
        out.append(node)
    return out


def rules(nodes):
    for node in nodes:
        if node.type == "qualified-rule":
            node.content = declarations(node.content)
        elif node.type == "at-rule" and node.content is not None:
            if node.lower_at_keyword in GROUPING:
                node.content = rules(tinycss2.parse_rule_list(node.content))
    return nodes


def main():
    src = sys.stdin.read()
    sheet = tinycss2.parse_stylesheet(src)
    errors = [n for n in sheet if n.type == "error"]
    if errors:
        sys.exit(f"important.py: parse error: {errors[0].message}")
    sys.stdout.write(tinycss2.serialize(rules(sheet)))


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        css = (
            '@-moz-document domain("a.org") { @media (x) { a { color: red; '
            "background: url(data:x;y) } } @keyframes k { to { top: 0 } } }"
        )
        out = tinycss2.serialize(rules(tinycss2.parse_stylesheet(css)))
        out = out.replace(" !important", "!important")
        assert "color: red!important" in out, out
        assert "url(data:x;y)!important" in out, out
        assert "top: 0 }" in out and "top: 0!important" not in out, out
        print("ok")
    else:
        main()
