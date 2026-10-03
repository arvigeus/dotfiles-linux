"""Offline tests: never contact repositories or execute a real upgrade."""

import importlib.util
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "backend", Path(__file__).with_name("backend.py")
)
if spec is None or spec.loader is None:
    raise RuntimeError("Cannot load test backend")
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.state = patch.object(backend, "STATE", Path(self.temporary.name))
        self.state.start()
        self.addCleanup(self.state.stop)
        # Never discover real extra managers or contact their registries in tests.
        executables = patch.object(backend.shutil, "which", return_value=None)
        executables.start()
        self.addCleanup(executables.stop)
        self.package = {
            "key": "sample",
            "name": "sample",
            "old": "1-1",
            "new": "2-1",
            "repo": "extra",
            "homepage": "https://example.org",
            "native_changelog": False,
        }
        self.plan = {
            "id": "plan",
            "distro": "arch",
            "created": time.time(),
            "installed": backend.digest(["sample 1-1"]),
            "packages": [self.package],
            "news": [],
            "evidence": {},
        }
        backend.save("plan.json", self.plan)

    def sources(self, absent=False):
        backend.save(
            "sources.json",
            {
                "arch:extra:sample": {
                    kind: {
                        "url": None if absent else f"https://example.org/{kind}",
                        "reason": "verified source",
                    }
                    for kind in ("upstream", "distro")
                }
            },
        )

    def evidence(self):
        with patch.object(backend, "fetch", return_value="Release 2: no migration required"):
            evidence = backend.evidence_for(self.plan, "sample")
        for index in range(len(evidence["documents"])):
            backend.dispatch({"action": "evidence", "key": "sample", "document": index})
        return evidence

    def test_atomic_state_roundtrip_and_permissions(self):
        backend.save("sample.json", {"null": None})
        self.assertEqual(backend.load("sample.json"), {"null": None})
        self.assertEqual((backend.STATE / "sample.json").stat().st_mode & 0o777, 0o600)

    def test_corrupt_state_is_not_silently_reset(self):
        (backend.STATE / "sources.json").write_text("broken")
        with self.assertRaisesRegex(RuntimeError, "Cannot read update state"):
            backend.load("sources.json", {})

    def test_null_skips_fetch_and_search_but_not_coverage_warning(self):
        self.sources(absent=True)
        with patch.object(
            backend, "fetch", side_effect=AssertionError("must not fetch")
        ):
            evidence = backend.evidence_for(self.plan, "sample")
        self.assertEqual(len(evidence["absent"]), 2)
        self.assertEqual(evidence["missing"], [])
        self.assertEqual(backend.status()["items"][0]["search_needed"], [])
        self.assertEqual(backend.status()["needs_ai"], [])
        self.assertEqual(backend.status()["items"][0]["review"]["decision"], "unavailable")

    def test_failed_fetch_does_not_turn_source_into_null(self):
        self.sources()
        with patch.object(backend, "fetch", side_effect=RuntimeError("offline")):
            evidence = backend.evidence_for(self.plan, "sample")
        self.assertEqual(len(evidence["errors"]), 2)
        self.assertIsNotNone(
            backend.load("sources.json")["arch:extra:sample"]["upstream"]["url"]
        )

    def test_unknown_has_persistent_cache_without_repeated_ai(self):
        evidence = self.evidence()
        backend.set_review(
            {
                "key": "sample",
                "hash": evidence["hash"],
                "decision": "unknown",
                "reason": "No sources yet",
            }
        )
        self.assertEqual(backend.status()["pending"], ["sample"])
        self.assertEqual(backend.status()["needs_ai"], [])

    def test_incomplete_evidence_cannot_be_marked_ready(self):
        evidence = self.evidence()
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            backend.set_review(
                {
                    "key": "sample",
                    "hash": evidence["hash"],
                    "decision": "ready",
                    "reason": "safe",
                }
            )

    def test_stale_evidence_hash_cannot_be_reviewed(self):
        self.sources()
        self.evidence()
        with self.assertRaisesRegex(ValueError, "changed"):
            backend.set_review(
                {
                    "key": "sample",
                    "hash": "wrong",
                    "decision": "ready",
                    "reason": "safe",
                }
            )

    def test_review_reused_only_for_matching_version_and_evidence(self):
        self.sources()
        evidence = self.evidence()
        backend.set_review(
            {
                "key": "sample",
                "hash": evidence["hash"],
                "decision": "ready",
                "reason": "Reviewed 1 to 2",
            }
        )
        self.assertEqual(backend.status()["needs_ai"], [])
        self.plan["packages"][0]["new"] = "3-1"
        backend.save("plan.json", self.plan)
        self.assertEqual(backend.status()["needs_ai"], ["sample"])

    def test_changed_source_invalidates_evidence(self):
        self.sources()
        self.evidence()
        with (
            patch.object(backend, "validate_url"),
            patch.object(backend, "fetch", return_value="release notes"),
        ):
            backend.set_source(
                {
                    "key": "sample",
                    "kind": "upstream",
                    "url": "https://example.org/new",
                    "reason": "verified",
                }
            )
        self.assertNotIn("sample", backend.load("plan.json")["evidence"])

    def test_forget_source_allows_new_search(self):
        self.sources(absent=True)
        backend.dispatch(
            {"action": "forget-source", "key": "sample", "kind": "upstream"}
        )
        self.assertEqual(backend.status()["items"][0]["search_needed"], ["upstream"])

    def test_evidence_pagination_preserves_complete_content(self):
        self.sources()
        with patch.object(backend, "fetch", return_value="0123456789" * 3000):
            evidence = backend.evidence_for(self.plan, "sample")
        page = backend.dispatch(
            {"action": "evidence", "key": "sample", "offset": 100, "limit": 10}
        )
        self.assertEqual(page["text"], "0123456789")
        self.assertEqual(page["total_chars"], 30000)
        self.assertEqual(page["hash"], evidence["hash"])
        with self.assertRaises(ValueError):
            backend.dispatch({"action": "status", "limit": 100})

    def test_check_fetches_changed_evidence_without_model(self):
        self.sources()
        evidence = self.evidence()
        backend.set_review(
            {
                "key": "sample",
                "hash": evidence["hash"],
                "decision": "ready",
                "reason": "1 to 2 reviewed",
            }
        )
        with (
            patch.object(backend, "distro", return_value="arch"),
            patch.object(backend, "candidates", return_value=[self.package]),
            patch.object(backend, "inventory", return_value=["sample 1-1"]),
            patch.object(backend, "arch_news", return_value=[]),
            patch.object(
                backend, "fetch", return_value="Release 2: no migration required"
            ),
        ):
            self.assertEqual(backend.scan()["needs_ai"], [])
        with (
            patch.object(backend, "distro", return_value="arch"),
            patch.object(backend, "candidates", return_value=[self.package]),
            patch.object(backend, "inventory", return_value=["sample 1-1"]),
            patch.object(backend, "arch_news", return_value=[]),
            patch.object(
                backend, "fetch", return_value="Release 2: migration required"
            ),
        ):
            self.assertEqual(backend.scan()["needs_ai"], ["sample"])

    def test_arch_inventory_uses_separate_database(self):
        response = subprocess.CompletedProcess(
            ["checkupdates"], 0, "sample 1-1 -> 2-1\n", ""
        )
        with (
            patch.object(
                backend.subprocess, "run", return_value=response
            ) as subprocess_run,
            patch.object(
                backend,
                "run",
                return_value="Repository      : extra\nURL             : https://example.org\n",
            ) as query,
        ):
            result = backend.candidates("arch")
        self.assertEqual(result[0]["repo"], "extra")
        self.assertIn("CHECKUPDATES_DB", subprocess_run.call_args.kwargs["env"])
        self.assertIn("--dbpath", query.call_args.args[0])
        self.assertNotIn("-Sy", query.call_args.args[0])

    def test_arch_exit_two_is_no_updates_but_failure_is_error(self):
        with patch.object(
            backend.subprocess,
            "run",
            return_value=subprocess.CompletedProcess([], 2, "", ""),
        ):
            self.assertEqual(backend.candidates("arch"), [])
        with (
            patch.object(
                backend.subprocess,
                "run",
                return_value=subprocess.CompletedProcess([], 1, "", "offline"),
            ),
            self.assertRaises(RuntimeError),
        ):
            backend.candidates("arch")

    def test_dnf4_and_dnf5_formats_and_multilib(self):
        for five in (False, True):
            with (
                self.subTest(dnf5=five),
                patch.object(backend, "dnf5", return_value=five),
                patch.object(
                    backend,
                    "inventory",
                    return_value=["sample.i686\t0:1-1", "sample.x86_64\t0:1-1"],
                ),
                patch.object(
                    backend,
                    "run",
                    return_value="sample\ti686\t2-1\tupdates\thttps://example.org\nsample\tx86_64\t2-1\tupdates\thttps://example.org\n",
                ) as query,
            ):
                packages = backend.candidates("fedora")
                self.assertEqual(len(packages), 2)
                self.assertEqual(query.call_args.args[0][-1].endswith("\\n"), five)

    def test_installonly_multiple_versions_are_not_discarded(self):
        with (
            patch.object(backend, "dnf5", return_value=True),
            patch.object(
                backend,
                "inventory",
                return_value=["kernel.x86_64\t0:1-1", "kernel.x86_64\t0:2-1"],
            ),
            patch.object(
                backend,
                "run",
                return_value="kernel\tx86_64\t3-1\tupdates\thttps://example.org\n",
            ),
        ):
            self.assertEqual(backend.candidates("fedora")[0]["old"], "0:1-1, 0:2-1")

    def test_fedora_fetches_distro_metadata_without_url(self):
        self.plan["distro"] = "fedora"
        self.package["native_changelog"] = True
        backend.save("plan.json", self.plan)
        with patch.object(backend, "run", return_value="RPM migration notes") as query:
            evidence = backend.evidence_for(self.plan, "sample")
        self.assertIn("--changelogs", query.call_args.args[0])
        self.assertEqual(len(evidence["documents"]), 1)
        self.assertEqual(evidence["missing"], ["upstream: not searched"])

    def test_news_dtd_and_empty_feed_fail_closed(self):
        for body in (
            '<!DOCTYPE rss [<!ENTITY x "boom">]><rss/>',
            "<rss><channel/></rss>",
        ):
            with patch.object(backend, "fetch", return_value=body), self.assertRaises(RuntimeError):
                backend.arch_news()

    def test_news_review_is_bound_to_installed_snapshot(self):
        evidence = {"hash": "hash"}
        key = backend.review_key(self.plan, "news:one", evidence)
        self.plan["installed"] = "changed"
        self.assertNotEqual(key, backend.review_key(self.plan, "news:one", evidence))

    def test_url_scheme_credentials_port_and_private_addresses(self):
        for url in (
            "file:///etc/passwd",
            "http://example.org",
            "https://user:password@example.org",
            "https://example.org:8443",
        ):
            with self.assertRaises(ValueError):
                backend.validate_url(url)
        with (
            patch.object(
                backend.socket,
                "getaddrinfo",
                return_value=[(0, 0, 0, "", ("127.0.0.1", 443))],
            ),
            self.assertRaises(ValueError),
        ):
            backend.validate_url("https://example.org")

    def test_no_apply_in_noninteractive_mode(self):
        with (
            patch.object(backend.sys.stdin, "isatty", return_value=False),
            patch.object(
                backend.subprocess,
                "run",
                side_effect=AssertionError("must not execute"),
            ),
            self.assertRaisesRegex(RuntimeError, "interactive"),
        ):
            backend.apply("plan")

    def test_apply_rejects_stale_plan_and_installed_drift(self):
        with (
            patch.object(backend.sys.stdin, "isatty", return_value=True),
            patch.object(backend.sys.stdout, "isatty", return_value=True),
        ):
            with self.assertRaisesRegex(RuntimeError, "Plan changed"):
                backend.apply("wrong")
            with (
                patch.object(backend, "distro", return_value="arch"),
                patch.object(backend, "inventory", return_value=["sample 2-1"]),
                self.assertRaisesRegex(RuntimeError, "Installed package state changed"),
            ):
                backend.apply("plan")

    def test_apply_rejects_changed_candidates_before_sudo(self):
        with (
            patch.object(backend.sys.stdin, "isatty", return_value=True),
            patch.object(backend.sys.stdout, "isatty", return_value=True),
            patch.object(backend, "distro", return_value="arch"),
            patch.object(backend, "inventory", return_value=["sample 1-1"]),
            patch.object(backend, "candidates", return_value=[]),
            patch.object(
                backend.subprocess,
                "run",
                side_effect=AssertionError("must not execute"),
            ),
            self.assertRaisesRegex(RuntimeError, "Upgrade candidates changed"),
        ):
            backend.apply("plan")

    def test_native_apply_keeps_confirmation_and_records_failures(self):
        for system, exit_code in (("arch", 0), ("fedora", 0), ("arch", 1)):
            with self.subTest(system=system, exit_code=exit_code):
                self.plan["distro"] = system
                evidence = {"key": "sample", "hash": "stable", "documents": [{"source": "mock", "text": "notes"}], "errors": [], "missing": []}
                self.plan["evidence"]["sample"] = evidence
                self.plan["reads"] = {"sample": {"hash": "stable", "documents": {"0": [[0, 5]]}}}
                backend.save("plan.json", self.plan)
                backend.set_review({"key": "sample", "hash": "stable", "decision": "ready", "reason": "mocked complete review"})
                (backend.STATE / "last-success.json").unlink(missing_ok=True)
                with (
                    patch.object(backend.sys.stdin, "isatty", return_value=True),
                    patch.object(backend.sys.stdout, "isatty", return_value=True),
                    patch.object(backend, "distro", return_value=system),
                    patch.object(backend, "inventory", side_effect=[["sample 1-1"], ["sample 2-1"]]),
                    patch.object(backend, "candidates", return_value=[self.package]),
                    patch.object(backend, "arch_news", return_value=[]),
                    patch.object(backend, "refresh_evidence"),
                    patch.object(backend, "cleanup", return_value={"removed": []}),
                    patch("builtins.print"),
                    patch.object(backend.subprocess, "run", return_value=subprocess.CompletedProcess([], exit_code)) as execute,
                ):
                    if exit_code:
                        with self.assertRaisesRegex(RuntimeError, "Update exited"):
                            backend.apply("plan")
                        self.assertIsNone(backend.load("last-success.json"))
                    else:
                        self.assertTrue(backend.apply("plan")["updated"])
                        self.assertEqual(backend.load("last-success.json")["plan"], "plan")
                    command = execute.call_args.args[0]
                    expected = ["sudo", "pacman", "-Syu"] if system == "arch" else ["sudo", "dnf", "upgrade", "--refresh"]
                    self.assertEqual(command, expected)
                    self.assertNotIn("--noconfirm", command)
                    self.assertNotIn("-y", command)
                self.assertEqual(backend.load("transaction.json")["exit_code"], exit_code)

    def test_lock_rejects_concurrent_writer(self):
        with backend.locked(), self.assertRaisesRegex(RuntimeError, "Another update"), backend.locked():
            pass

    def test_html_scripts_are_not_evidence(self):
        self.assertEqual(
            backend.readable("<html><script>evil()</script><p>Migration</p></html>"),
            "Migration",
        )


if __name__ == "__main__":
    unittest.main()
