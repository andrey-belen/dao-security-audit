// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VulnerableDAO - Reproduction of 2016 DAO Vulnerability
 * @author Security Audit Portfolio
 * @notice This contract recreates the infamous DAO reentrancy vulnerability for educational purposes
 * @dev DO NOT DEPLOY TO MAINNET - FOR SECURITY RESEARCH ONLY
 */
contract VulnerableDAO {
    mapping(address => uint256) public balances;
    mapping(address => bool) public members;
    
    uint256 public totalSupply;
    uint256 public constant MEMBER_STAKE = 1 ether;
    
    event Deposit(address indexed member, uint256 amount);
    event Withdrawal(address indexed member, uint256 amount);
    event MemberJoined(address indexed member);
    
    /**
     * @notice Join the DAO by depositing the required stake
     * @dev Members can deposit ETH to join the DAO
     */
    function joinDAO() external payable {
        require(msg.value >= MEMBER_STAKE, "Insufficient stake to join DAO");
        require(!members[msg.sender], "Already a member");
        
        members[msg.sender] = true;
        balances[msg.sender] += msg.value;
        totalSupply += msg.value;
        
        emit MemberJoined(msg.sender);
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @notice Deposit additional ETH to the DAO
     * @dev Only existing members can make additional deposits
     */
    function deposit() external payable {
        require(members[msg.sender], "Must be a member to deposit");
        require(msg.value > 0, "Must deposit more than 0");
        
        balances[msg.sender] += msg.value;
        totalSupply += msg.value;
        
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @notice Withdraw ETH from the DAO
     * @dev VULNERABLE: External call before state update (reentrancy vulnerability)
     * @param amount Amount of ETH to withdraw in wei
     */
    function withdraw(uint256 amount) external {
        require(members[msg.sender], "Must be a member to withdraw");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(amount > 0, "Must withdraw more than 0");
        
        // VULNERABILITY: External call before state update
        // This allows for reentrancy attacks
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        // State updates happen AFTER external call
        // VULNERABILITY: Using unchecked to allow underflow (replicating pre-0.8.0 behavior)
        unchecked {
            balances[msg.sender] -= amount;
            totalSupply -= amount;
        }
        
        emit Withdrawal(msg.sender, amount);
    }
    
    /**
     * @notice Get the contract's total ETH balance
     * @return Total ETH held by the contract
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @notice Check if an address is a DAO member
     * @param member Address to check
     * @return True if the address is a member
     */
    function isMember(address member) external view returns (bool) {
        return members[member];
    }
    
    /**
     * @notice Get the balance of a member
     * @param member Address of the member
     * @return Member's balance in wei
     */
    function getBalance(address member) external view returns (uint256) {
        return balances[member];
    }
}