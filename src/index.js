const leftPad = require("left-pad");
function greet(name) { return `Hello, ${leftPad(name, 12)}!`; }
if (require.main === module) console.log(greet("Muninn"));
module.exports = { greet };
