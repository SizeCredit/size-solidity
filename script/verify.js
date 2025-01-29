const libraries = require('../broadcast/Upgrade.s.sol/1/run-latest.json').libraries
const network = 'mainnet'

const libs = libraries.map(e => `--libraries ${e}`).join(' ')
const commands = libraries.map(e => `forge verify-contract ${e.split(':')[e.split(':').length-1]} ${e.replace(/:0x.*$/, '')} ${libs} --rpc-url ${network} --watch`).join('; ')

console.log(commands)