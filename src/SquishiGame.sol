// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";

/// @notice SushiToken Battle Royale on Polygon.
contract SquishiGame {
    event Join(address indexed player);
    event Hit(address indexed hitter, address indexed victim);
    event Heal(address indexed healer, address indexed friend);
    event Death(address indexed player);
    event ClaimWinnings(address indexed player, uint256 indexed winnings);
    
    /// @dev Token for winnings.
    ERC20 public immutable token;
    
    /// @dev Game variables:
    uint256 public immutable cutOff;
    uint256 public immutable gameEnds;
    uint256 public immutable restingRate;
    uint256 public immutable potDeposit;
    uint256 public immutable burnDeposit;
    uint256 public immutable startingHealth;
    
    uint256 public players;
    uint256 internal finalPot;
    uint256 public potClaimed;

    constructor (
        ERC20 _token, 
        uint256 _cutOff, 
        uint256 _gameEnds, 
        uint256 _restingRate,
        uint256 _potDeposit,
        uint256 _burnDeposit,
        uint256 _startingHealth
    ) {
        token = _token;
        cutOff = _cutOff;
        gameEnds = _gameEnds;
        restingRate = _restingRate;
        potDeposit = _potDeposit;
        burnDeposit = _burnDeposit;
        startingHealth = _startingHealth;
    }
    
    mapping(address => bool) public claimers;
    mapping(address => bool) public rip; /// @dev Confirms player death.
    mapping(address => uint256) public health;
    mapping(address => uint256) public lastActionTimestamp;
    
    uint256 internal unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 2;
        _;
        unlocked = 1;
    }
    
    modifier rested() {
        require(block.timestamp - lastActionTimestamp[msg.sender] > restingRate);
        _;
    }
    
    // **** JOIN ****
    
    /// @notice Deposit sushi and join game.
    function join() public lock {
        require(block.timestamp < gameEnds, "GAME_OVER");
        require(!rip[msg.sender], "ALREADY_DEAD");
        require(!isAlive(msg.sender), "ALREADY_PLAYING");
        require(
            token.transferFrom(msg.sender, address(this), potDeposit)
            &&
            token.transfer(address(0xdead), burnDeposit)
            , "TKN_TXS_FAILED"
        );
        
        health[msg.sender] = startingHealth;
        players++;
        
        emit Join(msg.sender);
    }

    // **** PLAY ****
    
    function pot() public view returns (uint256 value) {
        value = token.balanceOf(address(this));
    }
    
    /// @notice Check if player is still alive.
    function isAlive(address player) public view returns (bool alive) {
        alive = health[player] > 0;
    }
    
    /// @notice Attack another player.
    function hit(address victim) public lock rested {
        require(isAlive(msg.sender), "YOU_ARE_DEAD");
        require(isAlive(victim), "THEY_ARE_DEAD");
        
        health[victim] = health[victim] - 1;

        lastActionTimestamp[msg.sender] = block.timestamp;
        
        emit Hit(msg.sender, victim);
        
        if (health[victim] == 0) {
            players--;
            rip[victim] = true;
            emit Death(victim);
        }
    }
    
    /// @notice Heal another player.
    function heal(address friend) public lock rested {
        require(isAlive(msg.sender), "YOU_ARE_DEAD");
        require(isAlive(friend), "THEY_ARE_DEAD");
        require(health[friend] < startingHealth, "ALREADY_HEALED");
        
        health[friend] = health[friend] + 1; 
        
        lastActionTimestamp[msg.sender] = block.timestamp;
        
        emit Heal(msg.sender, friend);
    }
    
    // **** WIN ****
    
    /// @notice Remaining players can claim fair share of sushi pot.
    function claimWinnings() public lock {
        require(block.timestamp >= gameEnds, "GAME_NOT_OVER");
        require(isAlive(msg.sender), "DEAD");
        require(!claimers[msg.sender], "CLAIMED");
        
        if (potClaimed == 0) {
            finalPot = pot();
        }
        
        uint256 claim = finalPot / players;
        
        token.transfer(msg.sender, claim);
        
        potClaimed += claim;
        
        claimers[msg.sender] = true;
        
        emit ClaimWinnings(msg.sender, claim);
    }
}
