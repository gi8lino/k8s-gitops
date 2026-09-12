"""Run with python3 -m unittest discover -s hack/tests."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "cleanup_k8up_jobs.sh"


class CleanupTests(unittest.TestCase):
    def run_cleanup(self, *args, pods="", fail=""):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mock = root / "kubectl"
            mock.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "with open(os.environ['CALL_LOG'], 'a') as log:\n"
                "    log.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                "if sys.argv[1] == os.environ['FAIL_COMMAND']:\n"
                "    sys.exit(1)\n"
                "if sys.argv[1] == 'get':\n"
                "    print(os.environ['PODS'], end='')\n"
            )
            mock.chmod(0o755)
            log = root / "calls.jsonl"
            result = subprocess.run(
                ["/bin/bash", str(SCRIPT), *args],
                env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}",
                     "CALL_LOG": str(log), "FAIL_COMMAND": fail, "PODS": pods},
                capture_output=True, text=True, check=False,
            )
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return result, calls

    def test_current_namespace_and_no_matches(self):
        result, calls = self.run_cleanup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 1)
        self.assertNotIn('--all-namespaces', calls[0])
        self.assertIn('--selector=k8upjob=true', calls[0])
        self.assertIn('.items[?(@.metadata.deletionTimestamp)]', calls[0][-1])
        self.assertIn('.metadata.ownerReferences[?(@.kind=="Job")].name', calls[0][-1])

    def test_all_namespaces_and_ownerless_pod(self):
        result, calls = self.run_cleanup(
            '-A', pods='alpha\tbackup-one\tjob-one\nbeta\torphan\t\nbeta\tbackup-two\tjob-two\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--all-namespaces', calls[0])
        self.assertEqual(len(calls), 5)
        for offset, namespace, pod, job in [(1, 'alpha', 'backup-one', 'job-one'),
                                             (3, 'beta', 'backup-two', 'job-two')]:
            self.assertEqual(calls[offset], ['delete', 'job', job, '--namespace', namespace,
                                             '--wait=false', '--ignore-not-found'])
            self.assertEqual(calls[offset + 1], ['patch', 'pod', pod, '--namespace', namespace,
                                                 '--type=merge', '--patch={"metadata":{"finalizers":null}}'])

    def test_failures_stop_further_mutations(self):
        for command, count in [('get', 1), ('delete', 2), ('patch', 3)]:
            with self.subTest(command=command):
                result, calls = self.run_cleanup(
                    pods='default\tpod-one\tjob-one\ndefault\tpod-two\tjob-two\n', fail=command)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(calls), count)

    def test_help_and_invalid_option_do_not_access_cluster(self):
        for option, code in [('--help', 0), ('--invalid', 1)]:
            result, calls = self.run_cleanup(option)
            self.assertEqual(result.returncode, code)
            self.assertEqual(calls, [])


if __name__ == '__main__':
    unittest.main()
