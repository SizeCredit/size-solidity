const libraries = require('../broadcast/ProposeSafeTxUpgradeToV1_8.s.sol/8453/run-latest.json').libraries
const network = 'base-production'

const libs = libraries.map(e => `--libraries ${e}`).join(' ')
const commands = libraries.map(e => `forge verify-contract ${e.split(':')[e.split(':').length-1]} ${e.replace(/:0x.*$/, '')} ${libs} --rpc-url ${network} --watch`).join('; ')

console.log(commands)