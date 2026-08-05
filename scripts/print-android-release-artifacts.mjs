import { stdout } from 'node:process';

import { createAndroidReleaseArtifactPlan } from './release-config.mjs';

const plan = createAndroidReleaseArtifactPlan();

for (const artifact of plan.apks) {
  stdout.write(`apk\t${artifact.abi}\t${artifact.source}\t${artifact.target}\n`);
}

stdout.write(`aab\t-\t${plan.aab.source}\t${plan.aab.target}\n`);
