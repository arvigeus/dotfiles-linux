"""Regression tests for unread news, evidence receipts, extras and safe cleanup."""

import importlib.util
import json
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("workflow_backend", Path(__file__).with_name("backend.py"))
if spec is None or spec.loader is None:
    raise RuntimeError("Cannot load backend")
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        state = patch.object(backend, "STATE", self.root)
        state.start()
        self.addCleanup(state.stop)
        binaries = patch.object(backend.shutil, "which", return_value=None)
        binaries.start()
        self.addCleanup(binaries.stop)
        self.package = {"key": "sample", "name": "sample", "old": "1-1", "new": "2-1",
                        "repo": "extra", "homepage": "", "native_changelog": False}
        self.article = {"key": "news:one", "url": "https://example.org/news", "title": "Intervention",
                        "date": "today", "text": "Migration needed"}
        self.plan = {"id": "plan", "distro": "arch", "created": time.time(),
                     "installed": backend.digest(["sample 1-1", "not-upgrading 4-1"]),
                     "installed_inventory": ["sample 1-1", "not-upgrading 4-1"],
                     "packages": [self.package], "news": [], "evidence": {}, "reads": {}}
        backend.save("plan.json", self.plan)

    def sources(self, urls=None):
        backend.save("sources.json", {"arch:extra:sample": {
            kind: {"urls": urls if urls is not None else [f"https://example.org/{kind}"], "reason": "verified", "scope": "rolling"}
            for kind in ("upstream", "distro")}})

    def evidence(self, text="Release 2: reviewed"):
        with patch.object(backend, "fetch", return_value=text):
            return backend.evidence_for(backend.plan_required(), "sample")

    def read_all(self, key):
        evidence = backend.plan_required()["evidence"][key]
        for index, doc in enumerate(evidence["documents"]):
            for offset in range(0, len(doc["text"]), 4000):
                backend.dispatch({"action": "evidence", "key": key, "document": index, "offset": offset})

    def review(self, key, decision="ready"):
        evidence = backend.plan_required()["evidence"][key]
        return backend.set_review({"key": key, "hash": evidence["hash"], "decision": decision,
                                   "reason": "Version coverage verified; source cited", "follow_up": "Check reboot hooks"})

    def stage_news(self):
        self.plan["packages"] = []
        self.plan["news"] = [self.article]
        backend.save("plan.json", self.plan)
        with patch.object(backend, "fetch", return_value="Complete intervention article"):
            backend.evidence_for(self.plan, "news:one")
        self.read_all("news:one")

    def test_empty_news_cannot_be_approved(self):
        self.plan["news"] = [self.article]
        with patch.object(backend, "fetch", return_value="<html><script>JS only</script></html>"):
            evidence = backend.evidence_for(self.plan, "news:one")
        self.assertTrue(evidence["errors"])
        self.assertFalse(evidence["documents"])
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            backend.set_review({"key": "news:one", "hash": evidence["hash"], "decision": "ready", "reason": "safe"})

    def test_empty_package_docs_are_errors_not_changelog_absence(self):
        self.sources()
        evidence = self.evidence("<html><style>hidden</style></html>")
        self.assertEqual(len(evidence["errors"]), 2)
        self.assertEqual(evidence["absent"], [])
        self.assertEqual(backend.status()["needs_ai"], [])  # deterministic transport/empty warning
        self.assertEqual(backend.status()["items"][0]["review"]["decision"], "unknown")

    def test_ready_requires_every_page_of_every_document(self):
        self.sources()
        self.evidence("a" * 9000)
        with self.assertRaisesRegex(ValueError, "Page every"):
            self.review("sample")
        backend.dispatch({"action": "evidence", "key": "sample", "offset": 0})
        backend.dispatch({"action": "evidence", "key": "sample", "offset": 8000})
        with self.assertRaisesRegex(ValueError, "Page every"):
            self.review("sample")  # middle and second document are unread
        self.read_all("sample")
        self.review("sample")
        self.assertEqual(backend.status()["pending"], [])
        self.assertEqual(backend.status()["items"][0]["review"]["follow_up"], "Check reboot hooks")

    def test_refresh_invalidates_read_receipts(self):
        self.sources()
        self.evidence()
        self.read_all("sample")
        with patch.object(backend, "fetch", return_value="Changed release notes"):
            backend.dispatch({"action": "evidence", "key": "sample", "refresh": True, "limit": 1})
        with self.assertRaisesRegex(ValueError, "Page every"):
            self.review("sample")

    def test_evidence_pages_cannot_overflow_extension_output(self):
        self.sources()
        self.evidence("漢" * 9000)
        page = backend.dispatch({"action": "evidence", "key": "sample"})
        self.assertLess(len(json.dumps(page, ensure_ascii=False).encode()), 40000)
        self.assertEqual(len(page["text"]), 4000)
        with self.assertRaises(ValueError):
            backend.dispatch({"action": "evidence", "key": "sample", "offset": 10000})

    def test_multiple_source_documents_and_version_scoping(self):
        self.sources([])
        with patch.object(backend, "fetch", return_value="Release notes"), patch.object(backend, "validate_url"):
            backend.set_source({"key": "sample", "kind": "upstream", "urls": ["https://example.org/v1", "https://example.org/v2"], "reason": "Verified range"})
            evidence = backend.evidence_for(backend.plan_required(), "sample")
        self.assertEqual(len(evidence["documents"]), 2)
        self.read_all("sample")
        self.review("sample")  # absent optional distro notes do not fabricate coverage
        plan = backend.plan_required()
        plan["packages"][0]["new"] = "3-1"
        backend.save("plan.json", plan)
        self.assertEqual(backend.status()["items"][0]["search_needed"], ["upstream"])

    def test_absence_stays_cached_across_versions_without_ai(self):
        self.sources([])
        self.evidence()
        plan = backend.plan_required()
        plan["packages"][0]["new"] = "3-1"
        backend.save("plan.json", plan)
        with patch.object(backend, "fetch", side_effect=AssertionError("no fetch for absent URLs")):
            backend.evidence_for(plan, "sample")
        self.assertEqual(backend.status()["needs_ai"], [])
        self.assertEqual(backend.status()["pending"], ["sample"])
        self.assertEqual(backend.status()["items"][0]["review"]["decision"], "unavailable")

    def test_source_reset_cannot_resurrect_checkpoint(self):
        self.sources()
        self.evidence()
        backend.dispatch({"action": "forget-source", "key": "sample", "kind": "upstream"})
        self.assertIsNone(backend.cached_evidence(backend.plan_required(), "sample"))
        self.assertEqual(backend.status()["items"][0]["search_needed"], ["upstream"])

    def test_partial_check_checkpoint_can_resume(self):
        self.sources()
        evidence = self.evidence()
        plan = backend.plan_required()
        plan["evidence"] = {}
        backend.save("plan.json", plan)
        self.assertTrue(backend.status()["items"][0]["evidence_cached"])
        self.assertEqual(backend.dispatch({"action": "evidence", "key": "sample"})["hash"], evidence["hash"])
        plan["created"] += 1
        backend.save("plan.json", plan)
        self.assertFalse(backend.status()["items"][0]["evidence_cached"])

    def test_inventory_includes_non_upgrading_packages(self):
        page = backend.dispatch({"action": "inventory", "key": "not-upgrading"})
        self.assertEqual(page["items"], ["not-upgrading 4-1"])
        with self.assertRaises(ValueError):
            backend.dispatch({"action": "inventory", "limit": 51})

    def test_resolved_news_stays_read_after_inventory_changes(self):
        self.stage_news()
        self.review("news:one")
        self.assertEqual(backend.pending_news([self.article]), [])
        with patch.object(backend, "fetch", side_effect=AssertionError("already read")):
            self.assertEqual(backend.build_evidence(backend.plan_required(), "news:one")["hash"], backend.plan_required()["evidence"]["news:one"]["hash"])
        changed = {**self.article, "text": "Updated intervention"}
        self.assertEqual(backend.pending_news([changed]), [changed])

    def test_unresolved_news_survives_feed_expiry_and_reuses_decision(self):
        self.stage_news()
        self.review("news:one", "attention")
        self.assertEqual(backend.pending_news([]), [self.article])
        plan = backend.plan_required()
        plan["installed"] = "changed-after-routine-update"
        backend.save("plan.json", plan)
        self.assertEqual(backend.status()["needs_ai"], [])
        self.assertEqual(backend.status()["items"][0]["review"]["decision"], "attention")

    def test_initial_news_has_no_silent_baseline(self):
        self.assertEqual(backend.pending_news([self.article]), [self.article])

    def test_reset_or_revised_feed_reopens_news_even_with_same_article_hash(self):
        self.stage_news()
        self.review("news:one")
        plan = backend.plan_required()
        plan["news"][0]["text"] = "Revised RSS summary, same article body"
        backend.save("plan.json", plan)
        self.assertEqual(backend.status()["needs_ai"], ["news:one"])
        plan["news"][0]["text"] = self.article["text"]
        backend.save("plan.json", plan)
        backend.dispatch({"action": "forget-news", "key": "news:one"})
        self.assertEqual(backend.status()["needs_ai"], ["news:one"])
        self.assertEqual(backend.pending_news([self.article]), [self.article])

    def test_npm_candidates_use_wanted_and_scope_prefix(self):
        output = json.dumps({"@scope/sample": {"current": "1.0.0", "wanted": "2.0.0", "latest": "3.0.0", "homepage": "https://example.org"}})
        with patch.object(backend.shutil, "which", side_effect=lambda name: name if name == "npm" else None), patch.object(backend, "run", side_effect=[str(self.root), output]) as query:
            packages, warnings = backend.extra_candidates()
        self.assertEqual(warnings, [])
        self.assertEqual(packages[0]["new"], "2.0.0")
        self.assertEqual(packages[0]["repo"], str(self.root))
        self.assertIn("--global", query.call_args.args[0])

    def test_npm_errors_are_not_no_updates(self):
        for output in ('{"error":{"code":"offline"}}', "bad json"):
            with patch.object(backend.shutil, "which", side_effect=lambda name: name if name == "npm" else None), patch.object(backend, "run", side_effect=[str(self.root), output]), self.assertRaises(RuntimeError):
                backend.extra_candidates()

    def test_linked_npm_entry_prevents_unreviewed_blanket_update(self):
        output = json.dumps({"sample": {"current": "1.0.0", "wanted": "2.0.0"}, "linked": {"current": "1.0.0", "wanted": "git"}})
        with patch.object(backend.shutil, "which", side_effect=lambda name: name if name == "npm" else None), patch.object(backend, "run", side_effect=[str(self.root), output]):
            packages, warnings = backend.extra_candidates()
        self.assertEqual(packages, [])
        self.assertIn("entire npm update skipped", warnings[0])

    def test_root_owned_npm_is_not_upgraded_with_sudo(self):
        with patch.object(backend.shutil, "which", side_effect=lambda name: name if name == "npm" else None), patch.object(backend, "run", return_value=str(self.root)) as query, patch.object(backend.os, "access", return_value=False):
            packages, warnings = backend.extra_candidates()
        self.assertEqual(packages, [])
        self.assertIn("no automatic sudo", warnings[0])
        self.assertEqual(query.call_count, 1)

    def test_flatpak_targets_bind_commit_even_when_version_unchanged(self):
        ref = "app/org.example.Sample/x86_64/stable"
        old = f"{ref}\t1.0\toldcommit\tflathub\n"
        new = f"{ref}\t1.0\tnewcommit\tflathub\n"
        with patch.object(backend.shutil, "which", side_effect=lambda name: name if name == "flatpak" else None), patch.object(backend, "run", side_effect=[old, new, "", ""]):
            packages, _ = backend.extra_candidates()
        self.assertEqual(packages[0]["new_commit"], "newcommit")
        self.assertEqual(packages[0]["name"], "org.example.Sample")
        self.assertEqual(packages[0]["scope"], "user")
        with self.assertRaises(RuntimeError):
            backend.flatpak_record("bad record")

    def test_topgrade_preview_is_allowlisted_and_has_no_hooks(self):
        npm = {**self.package, "manager": "npm"}
        def query(command):
            self.assertIn("--dry-run", command)
            self.assertEqual(command[command.index("--only") + 1:], ["node"])
            content = Path(command[command.index("--config") + 1]).read_text()
            self.assertIn("cleanup = false", content)
            self.assertNotIn("[pre_commands]", content)
            self.assertNotIn("[post_commands]", content)
            self.assertNotIn("--yes", command)
            return "npm update --global"
        with patch.object(backend.shutil, "which", return_value="topgrade"), patch.object(backend, "run", side_effect=query):
            report = backend.topgrade_preview([npm])
        self.assertTrue(report["available"])
        self.assertEqual(report["steps"], ["node"])

    def test_no_topgrade_or_extra_updates_does_not_spawn_preview(self):
        with patch.object(backend, "run", side_effect=AssertionError("must not run")):
            self.assertEqual(backend.topgrade_preview([])["steps"], [])
            self.assertFalse(backend.topgrade_preview([{"manager": "npm"}])["available"])

    def test_extra_only_apply_uses_topgrade_not_native_manager(self):
        npm = {**self.package, "key": "npm:sample", "manager": "npm"}
        self.plan.update(packages=[npm], installed=backend.digest([]), topgrade={"available": True})
        backend.save("plan.json", self.plan)
        backend.save("sources.json", {"npm:extra:sample": {"upstream": {"urls": [], "reason": "confirmed absent"}}})
        backend.evidence_for(self.plan, "npm:sample")
        commands = []
        def execute(_plan, command):
            commands.append(command)
            self.assertEqual(command[0], "topgrade")
            self.assertNotIn("--dry-run", command)
            self.assertEqual(command[command.index("--only") + 1:], ["node"])
            self.assertTrue(Path(command[command.index("--config") + 1]).exists())
        with patch.object(backend.sys.stdin, "isatty", return_value=True), patch.object(backend.sys.stdout, "isatty", return_value=True), patch.object(backend, "distro", return_value="arch"), patch.object(backend, "inventory", return_value=[]), patch.object(backend, "candidates", return_value=[]), patch.object(backend, "extra_candidates", side_effect=[([npm], []), ([], [])]), patch.object(backend.shutil, "which", return_value="topgrade"), patch.object(backend, "arch_news", return_value=[]), patch.object(backend, "cleanup", return_value={"removed": []}), patch.object(backend, "transaction", side_effect=execute), patch("builtins.print"):
            result = backend.apply("plan", allow_unresolved=True)
        self.assertEqual(result["outcome"], "completed")
        self.assertEqual(len(commands), 1)

    def test_direct_extra_fallback_has_no_autoconfirm_or_cleanup(self):
        commands = backend.extra_commands([{"manager": "npm"}, {"manager": "flatpak"}])
        self.assertEqual(commands[0], ["npm", "update", "--global"])
        self.assertEqual(commands[1:], [["flatpak", "update", "--user"], ["flatpak", "update", "--system"]])
        self.assertNotIn("--unused", sum(commands, []))
        self.assertNotIn("-y", sum(commands, []))

    def test_apply_rejects_extra_drift_before_execution(self):
        with patch.object(backend.sys.stdin, "isatty", return_value=True), patch.object(backend.sys.stdout, "isatty", return_value=True), patch.object(backend, "distro", return_value="arch"), patch.object(backend, "inventory", return_value=self.plan["installed_inventory"]), patch.object(backend, "candidates", return_value=[self.package]), patch.object(backend, "extra_candidates", return_value=([{"key": "new-extra"}], [])), patch.object(backend, "transaction", side_effect=AssertionError("must not run")), self.assertRaisesRegex(RuntimeError, "Extra-manager candidates changed"):
            backend.apply("plan")

    def test_changed_review_digest_invalidates_confirmation(self):
        self.sources([])
        self.evidence()
        displayed = backend.status()["review_digest"]
        # A concurrent reviewer adds a newly discovered action to the same plan.
        self.review("sample", "attention")
        self.assertNotEqual(displayed, backend.status()["review_digest"])
        with patch.object(backend.sys.stdin, "isatty", return_value=True), patch.object(backend.sys.stdout, "isatty", return_value=True), patch.object(backend, "distro", return_value="arch"), patch.object(backend, "inventory", return_value=self.plan["installed_inventory"]), patch.object(backend, "candidates", return_value=[self.package]), patch.object(backend, "arch_news", return_value=[]), patch.object(backend, "transaction", side_effect=AssertionError("must not execute")), self.assertRaisesRegex(RuntimeError, "Review decisions changed"):
            backend.apply("plan", allow_unresolved=True, approval=displayed)

    def test_no_op_has_no_transaction_or_success_marker(self):
        self.plan.update(packages=[], installed=backend.digest([]))
        backend.save("plan.json", self.plan)
        with patch.object(backend.sys.stdin, "isatty", return_value=True), patch.object(backend.sys.stdout, "isatty", return_value=True), patch.object(backend, "distro", return_value="arch"), patch.object(backend, "inventory", return_value=[]), patch.object(backend, "candidates", return_value=[]), patch.object(backend, "arch_news", return_value=[]), patch.object(backend, "transaction", side_effect=AssertionError("must not run")):
            result = backend.apply("plan")
        self.assertEqual(result["outcome"], "no-op")
        self.assertIsNone(backend.load("last-success.json"))

    def test_cli_result_is_bound_to_attempt_even_on_failure(self):
        with patch.object(backend.os, "geteuid", return_value=1000), patch.object(backend.sys, "argv", ["backend.py", "--apply", "plan", "--attempt", "unique-attempt"]), patch.object(backend, "apply", side_effect=RuntimeError("mock cancelled/interrupted")), patch("builtins.print"):
            self.assertEqual(backend.main(), 1)
        result = backend.dispatch({"action": "result", "key": "unique-attempt"})
        self.assertEqual(result["outcome"], "failed")
        with self.assertRaises(RuntimeError):
            backend.dispatch({"action": "result", "key": "different-attempt"})

    def test_cleanup_deletes_only_identical_user_owned_configs_and_old_evidence(self):
        config = self.root / "sample.conf"
        config.write_text("configuration")
        duplicate = self.root / "sample.conf.pacnew"
        duplicate.write_text("configuration")
        changed = self.root / "sample.conf.rpmnew"
        changed.write_text("changed configuration")
        backup = self.root / "sample.conf.pacsave"
        backup.write_text("configuration")
        link = self.root / "link.pacnew"
        link.symlink_to(duplicate)
        self.assertTrue(backend.redundant_config(duplicate))
        self.assertFalse(backend.redundant_config(changed))
        self.assertFalse(backend.redundant_config(backup))
        self.assertFalse(backend.redundant_config(link))
        duplicate.chmod(0o600)
        self.assertFalse(backend.redundant_config(duplicate), "different permissions are not redundant")
        duplicate.chmod(config.stat().st_mode & 0o777)
        stale = self.root / "evidence-stale.json"
        stale.write_text("{}")
        os.utime(stale, (0, 0))
        current = self.root / ("evidence-" + backend.digest("sample") + ".json")
        current.write_text("{}")
        os.utime(current, (0, 0))
        report = {"redundant_configs": [str(duplicate)], "configuration_files": [str(duplicate), str(changed), str(backup)], "dangling_links": ["/etc/missing-link"]}
        with patch.object(backend, "audit", return_value=report):
            result = backend.cleanup()
        self.assertFalse(duplicate.exists())
        self.assertFalse(stale.exists())
        self.assertTrue(changed.exists())
        self.assertTrue(backup.exists())
        self.assertTrue(current.exists())
        self.assertIn(str(changed), result["manual"])
        self.assertEqual(result["dangling_links"], ["/etc/missing-link"])


if __name__ == "__main__":
    unittest.main()
