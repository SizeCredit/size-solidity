const fs = require('fs');

function convertLogToUnitTest(log) {
  const lines = log.trim().split("\n");
  let testLines = ["function test_CryticToFoundry_XX() public {"];
  
  lines.forEach(line => {
      const match = line.match(/\d+\) (\w+)\.(\w+)\([^)]*\)\((.*?)\) \(block=(\d+), time=(\d+), .* sender=(0x\w+)\)/);
      if (!match) return;
      
      const [, , fnName, args, block, time, sender] = match;
      
      testLines.push(`\t\t_setUp2(${time}, ${block}, address(${sender}));`);
      
      const formattedArgs = args.split(',').map(arg => 
          arg.trim().startsWith("0x") ? `address(${arg.trim()})` : arg.trim()
      ).join(', ');
      
      testLines.push(`    ${fnName}(${formattedArgs});`);
  });
  
  testLines.push("}");
  
  return testLines.join("\n");
}




if (process.argv.length > 2) {
  // Read from file
  const filePath = process.argv[2];
  fs.readFile(filePath, 'utf8', (err, data) => {
      if (err) {
          console.error("Error reading file:", err);
          process.exit(1);
      }
      console.log(convertLogToUnitTest(data));
  });
} else {
  // Read from stdin
  let input = "";
  process.stdin.on('data', chunk => input += chunk);
  process.stdin.on('end', () => {
      console.log(convertLogToUnitTest(input));
  });
}