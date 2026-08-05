import { stdin, stdout } from 'node:process';

import { extractSingleCertificateSha256 } from './release-config.mjs';

stdin.setEncoding('utf8');

let output = '';
for await (const chunk of stdin) {
  output += chunk;
}

stdout.write(`${extractSingleCertificateSha256(output)}\n`);
