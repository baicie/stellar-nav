import { chmod, copyFile, mkdir, mkdtemp, writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import test from 'node:test';

const releaseScript = new URL('./release.sh', import.meta.url);

function git(cwd, ...args) {
  return execFileSync('git', args, { cwd, encoding: 'utf8' }).trim();
}

async function createReleaseFixture() {
  const root = await mkdtemp(join(tmpdir(), 'stellar-nav-release-test.'));
  const project = join(root, 'project');
  const remote = join(root, 'remote.git');
  const bin = join(root, 'bin');

  await Promise.all([mkdir(join(project, 'scripts'), { recursive: true }), mkdir(bin)]);
  execFileSync('git', ['init', '--bare', '--initial-branch=main', remote]);
  execFileSync('git', ['init', '--initial-branch=main', project]);
  await copyFile(releaseScript, join(project, 'scripts/release.sh'));
  await chmod(join(project, 'scripts/release.sh'), 0o755);
  await writeFile(join(project, 'README.md'), 'fixture\n');
  await writeFile(
    join(bin, 'pnpm'),
    `#!/usr/bin/env bash
set -euo pipefail
[[ "\${1:-}" == "check:release" ]]
[[ "\${RELEASE_VERSION:-}" == "0.0.2" ]]
`,
  );
  await chmod(join(bin, 'pnpm'), 0o755);

  git(project, 'config', 'user.name', 'Release Test');
  git(project, 'config', 'user.email', 'release-test@example.invalid');
  git(project, 'add', 'README.md', 'scripts/release.sh');
  git(project, 'commit', '-m', 'test: create release fixture');
  git(project, 'remote', 'add', 'origin', remote);
  git(project, 'push', '--set-upstream', 'origin', 'main');

  return { bin, project, remote };
}

function runRelease(fixture, ...args) {
  return spawnSync(join(fixture.project, 'scripts/release.sh'), args, {
    cwd: fixture.project,
    encoding: 'utf8',
    env: {
      ...process.env,
      PATH: `${fixture.bin}:${process.env.PATH}`,
      RELEASE_BRANCH: '',
      RELEASE_REMOTE: '',
    },
  });
}

test('release script dry-run validates the branch without creating a tag', async () => {
  const fixture = await createReleaseFixture();
  const result = runRelease(fixture, '0.0.2', '--dry-run');

  if (result.status !== 0) {
    throw new Error(`${result.stdout}\n${result.stderr}`);
  }
  assert.match(result.stdout, /dry-run: no tag created/);
  assert.equal(git(fixture.project, 'tag', '--list', 'v0.0.2'), '');
});

test('release script creates and pushes an annotated tag', async () => {
  const fixture = await createReleaseFixture();
  const result = runRelease(fixture, 'v0.0.2', '--message', 'Test v0.0.2');

  if (result.status !== 0) {
    throw new Error(`${result.stdout}\n${result.stderr}`);
  }
  assert.equal(git(fixture.project, 'cat-file', '-t', 'v0.0.2'), 'tag');
  assert.equal(
    git(fixture.project, 'rev-parse', 'v0.0.2^{}'),
    git(fixture.project, 'rev-parse', 'HEAD'),
  );
  assert.equal(
    git(fixture.project, '--git-dir', fixture.remote, 'rev-parse', 'refs/tags/v0.0.2^{}'),
    git(fixture.project, 'rev-parse', 'HEAD'),
  );
});

test('release script rejects a non-release branch', async () => {
  const fixture = await createReleaseFixture();
  git(fixture.project, 'switch', '-c', 'codex/not-main');

  const result = runRelease(fixture, '0.0.2', '--dry-run');

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must be on main/);
});

test('release script rejects a dirty working tree', async () => {
  const fixture = await createReleaseFixture();
  await writeFile(join(fixture.project, 'UNCOMMITTED.md'), 'not ready\n');

  const result = runRelease(fixture, '0.0.2', '--dry-run');

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /working tree not clean/);
});

test('release script rejects a local main that is ahead of the remote', async () => {
  const fixture = await createReleaseFixture();
  await writeFile(join(fixture.project, 'README.md'), 'local-only change\n');
  git(fixture.project, 'add', 'README.md');
  git(fixture.project, 'commit', '-m', 'test: make local main stale');

  const result = runRelease(fixture, '0.0.2', '--dry-run');

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /local main .* != origin\/main/);
});
