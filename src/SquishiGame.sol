// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";

/// @notice SushiToken Battle Royale on Polygon.
contract SquishiGame {
    event Join(address indexed player);
    event Hit(address indexed hitter, address indexed victim);
    event Heal(address indexed healer, address indexed friend);
    event Buff(address indexed buffer, address indexed friend);
    event Death(address indexed player);
    event ClaimWinnings(address indexed player, uint256 indexed winnings);

    /// @dev SushiToken
    ERC20 public immutable sushi;

    /// @dev Game variables:
    uint256 public immutable pot;
    uint256 public immutable gameEnds = block.timestamp + 9 days;
    uint256 public players;
    uint256 internal finalPot;
    uint256 public potClaimed;

    constructor(ERC20 _sushi) {
        sushi = _sushi;
        pot = _sushi.balanceOf(address(this));
    }

    mapping(address => bool) public claimers;
    mapping(address => bool) public rip; /// @dev Confirms player death.
    mapping(address => uint256) public health;
    mapping(address => uint256) public lastActionTimestamp;
    mapping(address => uint256) public buffs;

    uint256 internal unlocked = 1;
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
            sushi.transferFrom(msg.sender, address(this), 3 ether) &&
                /// @dev Burn 1 sushi to squishi gods.
                sushi.transfer(address(0xdead), 1 ether),
            "SUSHI_TXS_FAILED"
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

        // check if the victim has any buffs
        if (buffs[victim] == 0) {
            health[victim] = health[victim] - 1;
        } else {
            buffs[victim] = buffs[victim] - 1;
        }

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

    /// @notice Buffs another player, giving them temporary invincibility
    function buff(address friend) public lock rested {
        require(isAlive(msg.sender), "YOU_ARE_DEAD");
        require(isAlive(friend), "THEY_ARE_DEAD");

        buffs[friend] = buffs[friend] + 1;
        lastActionTimestamp[msg.sender] = block.timestamp;

        emit Buff(msg.sender, friend);
    }

    // **** WIN ****

    /// @notice Remaining players can claim fair share of sushi pot.
    function claimWinnings() public lock {
        require(block.timestamp >= gameEnds, "GAME_NOT_OVER");
        require(isAlive(msg.sender), "DEAD");
        require(!claimers[msg.sender], "CLAIMED");

        if (potClaimed == 0) {
            finalPot = pot;
        }

        uint256 claim = finalPot / players;

        sushi.transfer(msg.sender, claim);

        potClaimed += claim;

        claimers[msg.sender] = true;

        emit ClaimWinnings(msg.sender, claim);
    }
}
