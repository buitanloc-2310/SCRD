# Sky First Exam Portal

**Production domain:** https://exam.skyfirst.io.vn  
**Control portal:** https://scrd.skyfirst.io.vn

The Exam portal delivers the exam-taking runtime: launch-token redemption, candidate/attempt loading, revision-safe autosave, deadline enforcement, file responses, submission, server-side scoring and receipt generation. The candidate payload must not disclose answer keys or grading rubrics.

## Runtime rules

- Server time and deadline are authoritative.
- Attempt reads/writes use the configured D1 binding.
- Launch tokens are single-use; redeemed access tokens are short-lived.
- A write lease prevents concurrent tabs/devices from overwriting one another.
- Autosave uses answer revisions and rejects stale writes.
- Submit is idempotent and returns a server-generated receipt.
- Candidate responses do not include answer/rubric secrets.
- Private response files must use R2 metadata and backend authorization.
- Integrity events are signals for review, not automatic proof of misconduct.
- Camera, microphone and screen capture are not activated without an explicit user action.

## Tests

From the repository root, run:

```bash
npm run test
```

This runs JavaScript syntax checks, SCRD backend smoke tests, SCRD↔Exam integration tests against a temporary shared SQLite database, and the Exam validation suite. Tests do not connect to production D1/R2.

## Cloudflare configuration

Review `wrangler.json` before deployment. Replace `CONFIRM_ACTUAL_D1_DATABASE_NAME` with the exact database name from Cloudflare Dashboard. Confirm the D1 ID, `DB` binding, R2 bucket `scrd-files`, `FILES` binding and `CONTROL_ORIGIN` are correct for the target environment. Configure required secrets outside source control.

Do not deploy until the shared schema/migrations, DNS, bindings, secrets, and production rollback plan have been verified. See the repository root `README_VI.md` and `SECURITY_AUDIT_VI.md`.
