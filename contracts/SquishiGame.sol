// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.9;

/// @notice Minimal ERC-20 token interface.
interface IERC20Minimal { 
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice SushiToken Battle Royale on Polygon.
contract SquishiGame {
    event Join(address indexed player);
    event Hit(address indexed hitter, address indexed victim);
    event Heal(address indexed healer, address indexed friend);
    event Death(address indexed player);
    event ClaimWinnings(address indexed player, uint256 indexed winnings);
    
    /// @dev SushiToken on Polygon:
    IERC20Minimal public constant sushi = IERC20Minimal(0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a);
    
    /// @dev Game variables:
    uint256 public immutable gameEnds = block.timestamp + 9 days;
    uint256 public players;
    uint256 public pot = sushi.balanceOf(address(this));
    uint256 internal finalpot;
    uint256 public potClaimed;
    
    mapping(address => bool) public claimers;
    mapping(address => bool) public rip; /// @dev Confirms player death.
    mapping(address => uint256) public health;
    mapping(address => uint256) public lastActionTimestamp;
    
    uint256 internal unlocked;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 2;
        _;
        unlocked = 1;
    }
    
    modifier rested() {
        require(block.timestamp - lastActionTimestamp[msg.sender] > 1 hours);
        _;
    }
    
    // **** JOIN ****
    
    /// @notice Deposit sushi and join game.
    function join() public lock {
        require(block.timestamp < gameEnds, "GAME_OVER");
        require(!rip[msg.sender], "ALREADY_DEAD");
        require(!isAlive(msg.sender), "ALREADY_PLAYING");
        require(
            /// @dev Take 3 sushi to give life to new player.
            sushi.transferFrom(msg.sender, address(this), 3 ether)
            &&
            /// @dev Burn 1 sushi to squishi gods.
            sushi.transfer(address(0xdead), 1 ether)
            , "SUSHI_TXS_FAILED"
        );
        
        health[msg.sender] = 9;
        players++;
        
        emit Join(msg.sender);
    }

    // **** PLAY ****
    
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
        require(health[friend] < 9, "ALREADY_HEALED");
        
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
            finalpot = pot;
        }
        
        uint256 claim = finalpot / players;
        
        sushi.transfer(msg.sender, claim);
        
        potClaimed += claim;
        
        claimers[msg.sender] = true;
        
        emit ClaimWinnings(msg.sender, claim);
    }
}
