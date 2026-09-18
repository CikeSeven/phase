"""Build the shipped supervisor source locally; test real OS processes and pipes."""
import os
import pathlib
import signal
import struct
import subprocess
import tempfile
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class ProcessRunnerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='phase_runner_')
        cls.runner = pathlib.Path(cls.temp.name) / 'runner'
        subprocess.run(['cc', '-Wall', '-Wextra', '-Werror', str(ROOT / 'tool/native/process_runner.c'), '-o', str(cls.runner)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def start(self, command):
        result = pathlib.Path(self.temp.name) / f'exit-{time.monotonic_ns()}'
        process = subprocess.Popen([str(self.runner), str(result), '/bin/sh', '-c', command], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        magic, pid = struct.unpack('<II', process.stdout.read(8))
        self.assertEqual(magic, 0x50484153)
        self.assertEqual(pid, process.pid)
        return process, result

    def test_output_stdin_and_real_nonzero_status(self):
        process, result = self.start('read value; printf "out:%s" "$value"; printf err >&2; exit 23')
        stdout, stderr = process.communicate(b'hello\n', timeout=3)
        self.assertEqual((stdout, stderr, process.returncode), (b'out:hello', b'err', 23))
        self.assertEqual(result.read_text(), '23 0\n')

    def test_group_and_detached_descendants_are_reaped(self):
        child_file = pathlib.Path(self.temp.name) / 'child'
        process, result = self.start(f"setsid /bin/sh -c 'echo $$ > {child_file}; sleep 60' & wait")
        for _ in range(100):
            if child_file.exists():
                break
            time.sleep(.01)
        pid = int(child_file.read_text())
        process.send_signal(signal.SIGTERM)
        process.communicate(timeout=4)
        self.assertFalse(pathlib.Path(f'/proc/{pid}').exists())
        self.assertTrue(result.exists())

    def test_background_children_do_not_outlive_success(self):
        process, _ = self.start('sleep 60 & printf done')
        stdout, _ = process.communicate(timeout=4)
        self.assertEqual(stdout, b'done')
        self.assertEqual(process.returncode, 0)

    def test_large_stdout_and_stderr_can_be_drained_together(self):
        process, _ = self.start('head -c 1048576 /dev/zero & head -c 1048576 /dev/zero >&2; wait')
        stdout, stderr = process.communicate(timeout=4)
        self.assertEqual(len(stdout), 1048576)
        self.assertEqual(len(stderr), 1048576)


if __name__ == '__main__':
    unittest.main()
