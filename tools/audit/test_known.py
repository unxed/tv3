#!/usr/bin/env python3
"""Tests of the list of known matches of borrow-audit.py (--known, tools/audit/known.txt).

The reference and the source are small Pascal texts written here; no corpus is needed.
usage: python3 -m unittest discover -s tools/audit -p 'test_*.py'
"""
import os
import re
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
AUDIT = os.path.join(HERE, 'borrow-audit.py')
REVIEW = 'https://github.com/unxed/tv3/issues/3#issuecomment-6320902977'


def body(changed=None):
    """A routine body of 20 statements of 6 tokens; statement `changed` gets another operator."""
    lines = ['program p;', 'begin']
    for i in range(20):
        op = '-' if i == changed else '+'
        lines.append('  A%d := B%d %s %d;' % (i, i, op, i + 1))
    lines.append('end.')
    return '\n'.join(lines) + '\n'


class KnownMatches(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        d = self.dir.name
        os.makedirs(os.path.join(d, 'corpus', 'lib'))
        os.makedirs(os.path.join(d, 'src'))
        self.ref = os.path.join(d, 'corpus', 'lib', 'ref.pas')
        with open(self.ref, 'w') as fh:
            fh.write(body())
        self.list = os.path.join(d, 'corpus', 'list.txt')
        with open(self.list, 'w') as fh:
            fh.write(self.ref + '\n')
        self.src = os.path.join(d, 'src', 'mine.pas')
        self.known = os.path.join(d, 'known.txt')

    def tearDown(self):
        self.dir.cleanup()

    def audit(self, source, known=None):
        with open(self.src, 'w') as fh:
            fh.write(source)
        cmd = [sys.executable, AUDIT, '--ref', self.list, '--cache', '']
        if known is not None:
            with open(self.known, 'w') as fh:
                fh.write(known)
            cmd += ['--known', self.known]
        env = dict(os.environ, PYTHONHASHSEED='0')
        return subprocess.run(cmd + [os.path.join(self.dir.name, 'src')], capture_output=True, text=True, env=env)

    def entry(self, out, line_delta=0):
        """The --known line for the one match of out."""
        m = re.search(r'^raw\s+(\d+)\s+\S+\s+==\s+\S+:(\d+)\n\s+window ([0-9a-f]{64})$', out, re.M)
        self.assertIsNotNone(m, out)
        return 'raw\t%s\t%s\tlib/ref.pas:%d\t%s\ttest\n' % (m.group(1), m.group(3), int(m.group(2)) + line_delta,
                                                          REVIEW)

    def test_match_without_list(self):
        r = self.audit(body())
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn('1 matches', r.stdout)

    def test_known_match_is_not_counted(self):
        known = self.entry(self.audit(body()).stdout)
        r = self.audit(body(), known)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn('0 matches', r.stdout)
        self.assertIn('1 known matches not counted', r.stdout)
        self.assertRegex(r.stdout, r'(?m)^known raw ')

    def test_one_token_changed_is_a_match_again(self):
        known = self.entry(self.audit(body()).stdout)
        # the last statements differ by one token: the run is shorter and its window another
        r = self.audit(body(changed=17), known)
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn('1 matches', r.stdout)

    def test_other_line_of_the_reference_is_a_match_again(self):
        known = self.entry(self.audit(body()).stdout, line_delta=1)
        r = self.audit(body(), known)
        self.assertEqual(r.returncode, 1, r.stdout)

    def test_other_window_is_a_match_again(self):
        known = self.entry(self.audit(body()).stdout)
        w = re.search(r'[0-9a-f]{64}', known).group(0)
        known = known.replace(w, ('0' if w[0] != '0' else '1') + w[1:])
        r = self.audit(body(), known)
        self.assertEqual(r.returncode, 1, r.stdout)

    def test_bad_line_stops_the_audit(self):
        r = self.audit(body(), 'raw 30 deadbeef lib/ref.pas:1\n')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('not "comparison', r.stderr)

    def test_list_of_the_repository(self):
        path = os.path.join(HERE, 'known.txt')
        if os.path.isfile(path):
            r = subprocess.run([sys.executable, '-c', 'import importlib.util as u, sys; s = u.spec_from_file_location('
                                '"a", sys.argv[1]); m = u.module_from_spec(s); s.loader.exec_module(m); '
                                'print(len(m.load_known(sys.argv[2])))', AUDIT, path], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == '__main__':
    unittest.main()
