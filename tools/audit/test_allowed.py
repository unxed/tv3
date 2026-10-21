#!/usr/bin/env python3
"""Tests of the allowed sources of borrow-audit.py (--allowed, the list that tools/audit/fetch-corpora.sh writes).

A window of a reference that also occurs in an allowed source does not count. The allowed C++ sources of tv3 are
magiblot/tvision and magiblot/tvterm at the commits that CLAUDE.md names (rule 4). The reference and the sources are
small texts written here; no corpus is needed.
usage: python3 -m unittest discover -s tools/audit -p 'test_*.py'
"""
import os
import re
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
AUDIT = os.path.join(HERE, 'borrow-audit.py')
FETCH = os.path.join(HERE, 'fetch-corpora.sh')
RULES = os.path.join(ROOT, 'CLAUDE.md')

# twelve literals, all of them significant and no two of them one apart: a run that the lit comparison counts
VALUES = [1000, 2731, 4096, 513, 777, 9001, 65, 300, 4242, 1234, 5555, 8080]


def c_table(values):
    return 'static const int table[] = {%s};\n' % ', '.join(str(v) for v in values)


def pascal_table(values):
    return ('unit u;\ninterface\nconst\n  Table: array[0..%d] of Integer = (%s);\nimplementation\nend.\n'
            % (len(values) - 1, ', '.join(str(v) for v in values)))


class AllowedSources(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        d = self.dir.name
        for sub in ('corpus/other', 'corpus/tvterm/source/tvterm-core', 'src'):
            os.makedirs(os.path.join(d, sub))
        self.ref = os.path.join(d, 'corpus', 'other', 'ref.cc')
        with open(self.ref, 'w') as fh:
            fh.write(c_table(VALUES))
        self.list = os.path.join(d, 'corpus', 'list.txt')
        with open(self.list, 'w') as fh:
            fh.write(self.ref + '\n')
        self.allowed_src = os.path.join(d, 'corpus', 'tvterm', 'source', 'tvterm-core', 'allowed.cc')
        self.allowed = os.path.join(d, 'corpus', 'allowed.txt')
        with open(os.path.join(d, 'src', 'mine.pas'), 'w') as fh:
            fh.write(pascal_table(VALUES))

    def tearDown(self):
        self.dir.cleanup()

    def audit(self, allowed_text=None):
        cmd = [sys.executable, AUDIT, '--ref', self.list, '--cache', '']
        if allowed_text is not None:
            with open(self.allowed_src, 'w') as fh:
                fh.write(allowed_text)
            with open(self.allowed, 'w') as fh:
                fh.write(self.allowed_src + '\n')
            cmd += ['--allowed', self.allowed]
        env = dict(os.environ, PYTHONHASHSEED='0')
        return subprocess.run(cmd + [os.path.join(self.dir.name, 'src')], capture_output=True, text=True, env=env)

    def test_match_without_allowed_source(self):
        r = self.audit()
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertRegex(r.stdout, r'(?m)^lit\s+12 ')

    def test_window_of_an_allowed_cc_file_is_not_counted(self):
        r = self.audit(c_table(VALUES))
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn('0 matches', r.stdout)

    def test_other_window_of_an_allowed_file_does_not_help(self):
        r = self.audit(c_table(VALUES[:6] + [7007] + VALUES[7:]))
        self.assertEqual(r.returncode, 1, r.stdout)


class PinnedSources(unittest.TestCase):
    """fetch-corpora.sh takes each allowed repository at the commit that rule 4 of CLAUDE.md names."""

    def setUp(self):
        with open(FETCH, encoding='utf-8') as fh:
            self.fetch = fh.read()
        with open(RULES, encoding='utf-8') as fh:
            self.rules = ' '.join(fh.read().split())

    def pinned(self, repo):
        m = re.search(r'git clone [^\n]*https://github\.com/%s (\S+)\n(?:.*\n)*?.*checkout -q ([0-9a-f]{7,40})\n'
                      % re.escape(repo), self.fetch)
        self.assertIsNotNone(m, repo)
        return m.group(2)

    def test_tvision(self):
        self.assertIn('magiblot/tvision @ %s' % self.pinned('magiblot/tvision')[:7], self.rules)

    def test_tvterm(self):
        self.assertIn('magiblot/tvterm @ %s' % self.pinned('magiblot/tvterm')[:7], self.rules)

    def test_tvterm_sources_are_allowed(self):
        allowed = self.fetch[self.fetch.index('> list.txt'):]
        self.assertIn("find tvterm/source tvterm/include -type f \\( -name '*.cc'", allowed)


if __name__ == '__main__':
    unittest.main()
