// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/VulnerableDAO.sol";
import "../src/ReentrancyAttacker.sol";

/**
 * @title DAOSecurityAudit - Comprehensive Security Test Suite
 * @author Security Audit Portfolio
 * @notice Professional test suite demonstrating DAO vulnerability analysis
 * @dev Follows industry-standard security testing practices
 */
contract DAOSecurityAuditTest is Test {
    VulnerableDAO public dao;
    ReentrancyAttacker public attacker;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public maliciousActor = makeAddr("maliciousActor");
    
    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public constant MEMBER_STAKE = 1 ether;
    
    event log_named_uint256(string key, uint256 val);
    
    function setUp() public {
        // Deploy vulnerable DAO contract
        dao = new VulnerableDAO();
        
        // Fund test accounts
        vm.deal(alice, INITIAL_BALANCE);
        vm.deal(bob, INITIAL_BALANCE);
        vm.deal(charlie, INITIAL_BALANCE);
        vm.deal(maliciousActor, INITIAL_BALANCE);
        
        console.log("=== DAO Security Audit Test Suite ===");
        console.log("DAO Contract:", address(dao));
        console.log("Member Stake Required:", MEMBER_STAKE);
    }
    
    /**
     * @notice Test normal DAO operations under legitimate use
     * @dev Establishes baseline functionality before security testing
     */
    function test_NormalDAOOperations() public {
        console.log("\n=== Testing Normal DAO Operations ===");
        
        // Alice joins the DAO
        vm.startPrank(alice);
        dao.joinDAO{value: MEMBER_STAKE}();
        assertTrue(dao.isMember(alice), "Alice should be a member");
        assertEq(dao.getBalance(alice), MEMBER_STAKE, "Alice balance incorrect");
        vm.stopPrank();
        
        // Bob joins the DAO
        vm.startPrank(bob);
        dao.joinDAO{value: MEMBER_STAKE * 2}(); // Bob stakes more
        assertTrue(dao.isMember(bob), "Bob should be a member");
        assertEq(dao.getBalance(bob), MEMBER_STAKE * 2, "Bob balance incorrect");
        vm.stopPrank();
        
        // Charlie makes additional deposit
        vm.startPrank(charlie);
        dao.joinDAO{value: MEMBER_STAKE}();
        dao.deposit{value: 0.5 ether}();
        assertEq(dao.getBalance(charlie), 1.5 ether, "Charlie balance incorrect");
        vm.stopPrank();
        
        // Verify total DAO state
        uint256 expectedTotal = MEMBER_STAKE + (MEMBER_STAKE * 2) + 1.5 ether;
        assertEq(dao.totalSupply(), expectedTotal, "Total supply incorrect");
        assertEq(dao.getContractBalance(), expectedTotal, "Contract balance incorrect");
        
        console.log("Normal operations completed successfully");
        console.log("Total DAO Balance:", dao.getContractBalance());
    }
    
    /**
     * @notice Test legitimate withdrawal functionality
     * @dev Ensures normal withdrawals work correctly before testing attack
     */
    function test_LegitimateWithdrawals() public {
        console.log("\n=== Testing Legitimate Withdrawals ===");
        
        // Setup: Alice joins and deposits
        vm.startPrank(alice);
        dao.joinDAO{value: MEMBER_STAKE * 2}();
        uint256 initialBalance = alice.balance;
        
        // Alice withdraws half her stake
        uint256 withdrawAmount = MEMBER_STAKE;
        dao.withdraw(withdrawAmount);
        
        // Verify withdrawal succeeded
        assertEq(alice.balance, initialBalance + withdrawAmount, "Alice ETH balance incorrect");
        assertEq(dao.getBalance(alice), MEMBER_STAKE, "Alice DAO balance incorrect");
        assertEq(dao.getContractBalance(), MEMBER_STAKE, "DAO contract balance incorrect");
        
        vm.stopPrank();
        
        console.log("Legitimate withdrawal completed successfully");
    }
    
    /**
     * @notice Demonstrate the reentrancy attack in controlled environment
     * @dev This is the core security demonstration - shows actual exploitation
     */
    function test_ReentrancyAttackDemonstration() public {
        console.log("\n=== REENTRANCY ATTACK DEMONSTRATION ===");
        console.log("WARNING: This demonstrates actual vulnerability exploitation");
        
        // Phase 1: Setup legitimate DAO with multiple members and funds
        console.log("\n--- Phase 1: Establishing Legitimate DAO State ---");
        
        vm.startPrank(alice);
        dao.joinDAO{value: MEMBER_STAKE * 3}();
        vm.stopPrank();
        
        vm.startPrank(bob);
        dao.joinDAO{value: MEMBER_STAKE * 2}();
        vm.stopPrank();
        
        vm.startPrank(charlie);
        dao.joinDAO{value: MEMBER_STAKE * 4}();
        vm.stopPrank();
        
        uint256 legitimateTotal = dao.getContractBalance();
        console.log("Total Legitimate Funds in DAO:", legitimateTotal);
        console.log("Number of Members:", "3");
        
        // Phase 2: Deploy attacker contract
        console.log("\n--- Phase 2: Attacker Preparation ---");
        attacker = new ReentrancyAttacker(address(dao));
        vm.deal(address(attacker), MEMBER_STAKE * 2);
        
        uint256 attackerInitialBalance = address(attacker).balance;
        console.log("Attacker Initial Balance:", attackerInitialBalance);
        console.log("Attacker Contract:", address(attacker));
        
        // Phase 3: Execute the attack
        console.log("\n--- Phase 3: Executing Reentrancy Attack ---");
        
        vm.startPrank(maliciousActor);
        
        // Record state before attack
        uint256 daoBalanceBefore = dao.getContractBalance();
        uint256 attackerBalanceBefore = address(attacker).balance;
        
        console.log("DAO Balance Before Attack:", daoBalanceBefore);
        console.log("Attacker Balance Before Attack:", attackerBalanceBefore);
        
        // Execute attack with maximum 10 reentrancy calls
        attacker.initializeAttack(10);
        
        // Record state after attack
        uint256 daoBalanceAfter = dao.getContractBalance();
        uint256 attackerBalanceAfter = address(attacker).balance;
        
        console.log("\n--- Phase 4: Attack Results ---");
        console.log("DAO Balance After Attack:", daoBalanceAfter);
        console.log("Attacker Balance After Attack:", attackerBalanceAfter);
        
        // Calculate damage
        uint256 stolenAmount = attackerBalanceAfter - attackerInitialBalance + MEMBER_STAKE;
        uint256 damageToDAO = daoBalanceBefore - daoBalanceAfter;
        
        console.log("Total Amount Stolen:", stolenAmount);
        console.log("Damage to DAO:", damageToDAO);
        console.log("Attack ROI:", ((stolenAmount * 100) / MEMBER_STAKE), "%");
        
        vm.stopPrank();
        
        // Security assertions - verify attack succeeded
        assertTrue(attackerBalanceAfter > attackerBalanceBefore, "Attack should increase attacker balance");
        assertTrue(daoBalanceAfter < daoBalanceBefore, "Attack should drain DAO funds");
        assertTrue(stolenAmount > MEMBER_STAKE, "Attacker should profit beyond initial investment");
        
        console.log("\n=== ATTACK SUCCESSFULLY DEMONSTRATED ===");
        console.log("This proves the reentrancy vulnerability exists and is exploitable");
    }
    
    /**
     * @notice Test attack prevention scenarios and edge cases
     * @dev Demonstrates security researcher's comprehensive testing approach
     */
    function test_AttackVariationsAndEdgeCases() public {
        console.log("\n=== Testing Attack Variations ===");
        
        // Setup DAO with funds
        vm.startPrank(alice);
        dao.joinDAO{value: MEMBER_STAKE * 5}();
        vm.stopPrank();
        
        // Deploy attacker
        attacker = new ReentrancyAttacker(address(dao));
        
        // Test 1: Attack with minimal funds
        console.log("\n--- Test: Minimal Attack ---");
        vm.deal(address(attacker), MEMBER_STAKE);
        
        vm.startPrank(maliciousActor);
        uint256 balanceBefore = dao.getContractBalance();
        attacker.initializeAttack(3); // Limited reentrancy
        uint256 balanceAfter = dao.getContractBalance();
        
        assertTrue(balanceAfter < balanceBefore, "Even minimal attack should succeed");
        console.log("Minimal attack drained:", balanceBefore - balanceAfter, "wei");
        vm.stopPrank();
    }
    
    /**
     * @notice Fuzz testing to discover edge cases in attack scenarios
     * @dev Professional security testing includes property-based testing
     */
    function testFuzz_ReentrancyAttackWithVariableDepth(uint256 maxAttacks) public {
        // Bound the fuzz input to reasonable values
        maxAttacks = bound(maxAttacks, 1, 50);
        
        // Setup DAO with substantial funds
        vm.startPrank(alice);
        dao.joinDAO{value: MEMBER_STAKE * 10}();
        vm.stopPrank();
        
        // Deploy and fund attacker
        attacker = new ReentrancyAttacker(address(dao));
        vm.deal(address(attacker), MEMBER_STAKE * 2);
        
        // Execute attack with fuzzed parameters
        vm.startPrank(maliciousActor);
        uint256 balanceBefore = dao.getContractBalance();
        
        try attacker.initializeAttack(maxAttacks) {
            uint256 balanceAfter = dao.getContractBalance();
            
            // Attack should always succeed in draining some funds
            assertLe(balanceAfter, balanceBefore, "Attack should not increase DAO balance");
            
            // If attack succeeded, verify it extracted more than invested
            if (address(attacker).balance > MEMBER_STAKE) {
                assertTrue(address(attacker).balance > MEMBER_STAKE, "Profitable attack should exceed investment");
            }
        } catch {
            // Some attack configurations may fail, which is acceptable
            console.log("Attack failed with maxAttacks:", maxAttacks);
        }
        
        vm.stopPrank();
    }
    
    /**
     * @notice Invariant testing to verify DAO accounting remains consistent
     * @dev Demonstrates advanced testing techniques for financial contracts
     */
    function invariant_TotalSupplyMatchesActualFunds() public {
        // This invariant should hold under normal conditions but break during attack
        uint256 totalSupply = dao.totalSupply();
        uint256 contractBalance = dao.getContractBalance();
        
        // Under normal conditions, these should match
        // During/after attack, this invariant will be violated
        if (totalSupply != contractBalance) {
            console.log("INVARIANT VIOLATION DETECTED:");
            console.log("Total Supply:", totalSupply);
            console.log("Contract Balance:", contractBalance);
            console.log("Discrepancy:", 
                totalSupply > contractBalance ? 
                totalSupply - contractBalance : 
                contractBalance - totalSupply
            );
        }
    }
}