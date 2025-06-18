#!/usr/bin/env node

const fs = require('fs');
const ethers = require('ethers');

function toChecksumAddress(address) {
    address = address.replace('0x', '').padStart(40, '0');
    return ethers.utils.getAddress(`0x${address}`);
}

function parseArguments() {
    const args = process.argv.slice(2);
    if (args.length === 0) {
        console.error('Usage: node converter.js <CryticToFoundry.t.sol> [LOG_FILE]');
        process.exit(1);
    }
    
    const solidityFile = args[0];
    const logFile = args[1];
    
    return { solidityFile, logFile };
}

function readInput(logFile) {
    if (logFile) {
        return fs.readFileSync(logFile, 'utf8');
    } else {
        // Read from stdin
        return fs.readFileSync(0, 'utf8');
    }
}

function getLastTestNumber(solidityContent) {
    const testRegex = /function test_CryticToFoundry_(\d+)\(\)/g;
    let lastNumber = 0;
    let match;
    
    while ((match = testRegex.exec(solidityContent)) !== null) {
        const num = parseInt(match[1]);
        if (num > lastNumber) {
            lastNumber = num;
        }
    }
    
    return lastNumber;
}

function parseFailedTests(logContent) {
    const failedTests = [];
    
    // Parse Medusa failed tests (format: ⇾ [FAILED] Assertion Test: ...)
    const medusaFailureRegex = /⇾ \[FAILED\] Assertion Test: CryticTester\.(\w+)\([^)]*\)\s*\n[^[]*\[Call Sequence\]\s*((?:\d+\)[^⇾]*(?:\n(?!⇾)[^⇾]*)*)*)/g;
    
    let match;
    while ((match = medusaFailureRegex.exec(logContent)) !== null) {
        const methodName = match[1];
        const callSequence = match[2];
        
        const calls = parseCallSequence(callSequence, 'medusa');
        if (calls.length > 0) {
            failedTests.push({
                type: 'medusa',
                method: methodName,
                calls: calls
            });
        }
    }
    
    // Parse Echidna failed tests (format typically shows failed properties)
    // Look for patterns like "property_XXX: failed!" followed by call sequence
    const echidnaFailureRegex = /(\w+): failed!\s*Call sequence:\s*((?:(?:(?!\w+: failed!|\w+: passing).)*\n?)*)/gm;
    
    while ((match = echidnaFailureRegex.exec(logContent)) !== null) {
        const propertyName = match[1];
        const callSequence = match[2];
        
        const calls = parseEchidnaCallSequence(callSequence);
        if (calls.length > 0) {
            failedTests.push({
                type: 'echidna',
                method: propertyName,
                calls: calls
            });
        }
    }
    
    return failedTests;
}

function parseCallSequence(sequenceText, fuzzerType) {
    const calls = [];
    
    // Match individual call lines like:
    // 1) CryticTester.deposit(address,uint256)(0x1b8223, 2045995665600633298929287457024267145558078246600919483171327644479086004263) (block=23898, time=406129, gas=12500000, gasprice=1, value=0, sender=0x10000)
    const callRegex = /(\d+)\)\s+CryticTester\.(\w+)\([^)]*\)\(([^)]*)\)\s+\(block=(\d+),\s*time=(\d+),.*?sender=([^)]+)\)/g;
    
    let match;
    while ((match = callRegex.exec(sequenceText)) !== null) {
        const [_, stepNum, method, argsStr, block, time, sender] = match;
        
        const args = parseMethodArguments(argsStr);
        
        calls.push({
            step: parseInt(stepNum),
            method: method,
            args: args,
            block: parseInt(block),
            time: parseInt(time),
            sender: toChecksumAddress(sender)
        });
    }
    
    return calls;
}

function parseEchidnaCallSequence(sequenceText) {
    const calls = [];
    
    // Echidna format might be different - this is a placeholder
    // Example: "f(1,2) from: 0x123 Time delay: 100 Block delay: 10"
    const lines = sequenceText.split('\n').filter(line => line.trim());
    
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line) continue;
        
        // Try to parse Echidna call format
        const callMatch = line.match(/(\w+)\(([^)]*)\)(?:\s+from:\s+([^\s]+))?(?:\s+Time delay:\s+(\d+))?(?:\s+Block delay:\s+(\d+))?/);
        if (callMatch) {
            const [_, method, argsStr, sender, timeDelay, blockDelay] = callMatch;
            
            const args = parseMethodArguments(argsStr);
            
            calls.push({
                step: i + 1,
                method: method,
                args: args,
                timeDelay: timeDelay ? parseInt(timeDelay) : 0,
                blockDelay: blockDelay ? parseInt(blockDelay) : 0,
                sender: sender || 'USER1'
            });
        }
    }
    
    return calls;
}

function parseMethodArguments(argsStr) {
    if (!argsStr || !argsStr.trim()) return [];
    
    const args = [];
    let current = '';
    let parenCount = 0;
    let inString = false;
    
    for (let i = 0; i < argsStr.length; i++) {
        const char = argsStr[i];
        
        if (char === '"' && argsStr[i-1] !== '\\') {
            inString = !inString;
        }
        
        if (!inString) {
            if (char === '(') parenCount++;
            if (char === ')') parenCount--;
            
            if (char === ',' && parenCount === 0) {
                const arg = current.trim();
                if (arg.startsWith('0x')) {
                    args.push(toChecksumAddress(arg));
                } else {
                    args.push(arg);
                }
                current = '';
                continue;
            }
        }
        
        current += char;
    }
    
    if (current.trim()) {
        args.push(current.trim());
    }
    
    return args;
}

function generateSolidityTest(testNum, failedTest) {
    let code = `    function test_CryticToFoundry_${testNum.toString().padStart(2, '0')}() public {\n`;
    
    // Sort calls by step number
    const sortedCalls = failedTest.calls.sort((a, b) => a.step - b.step);
    
    let lastSender = null;
    let lastTime = 0;
    let lastBlock = 0;
    let cumulativeTime = 0;
    let cumulativeBlock = 0;
    
    for (const call of sortedCalls) {
        if (failedTest.type === 'medusa') {
            // Medusa format: absolute time and block values
            const timeIncrement = call.time - lastTime;
            const blockIncrement = call.block - lastBlock;
            
            if (call.sender !== lastSender || timeIncrement > 0 || blockIncrement > 0) {
                // Medusa uses _setUp2(time, block, sender)
                code += `        _setUp2(${call.time}, ${call.block}, ${call.sender});\n`;
                lastSender = call.sender;
                lastTime = call.time;
                lastBlock = call.block;
            }
        } else {
            // Echidna format: incremental time and block values
            if (call.sender !== lastSender || call.timeDelay > 0 || call.blockDelay > 0) {
                // Echidna uses _setUp(sender, timeIncrement, blockIncrement)
                code += `        _setUp(${call.sender}, ${call.timeDelay} seconds, ${call.blockDelay});\n`;
                lastSender = call.sender;
                cumulativeTime += call.timeDelay;
                cumulativeBlock += call.blockDelay;
            }
        }
        
        // Add the actual method call
        const argsStr = call.args.join(', ');
        code += `        ${call.method}(${argsStr});\n`;
    }
    
    code += `    }\n`;
    
    return code;
}

function main() {
    try {
        const { solidityFile, logFile } = parseArguments();
        
        // Read the existing Solidity file to get the last test number
        const solidityContent = fs.readFileSync(solidityFile, 'utf8');
        const lastTestNumber = getLastTestNumber(solidityContent);
        
        // Read the log content
        const logContent = readInput(logFile);
        
        // Parse failed tests
        const failedTests = parseFailedTests(logContent);
        
        if (failedTests.length === 0) {
            console.error('No failed tests found in the log.');
            process.exit(1);
        }
        
        // Generate new tests
        let output = '';
        let currentTestNumber = lastTestNumber;
        
        for (const failedTest of failedTests) {
            currentTestNumber++;
            const testCode = generateSolidityTest(currentTestNumber, failedTest);
            output += testCode + '\n';
        }
        
        // Output the generated tests
        console.log(output.trim());
        
    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

if (require.main === module) {
    main();
}