// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {DSTest} from "ds-test/test.sol";

import {MockERC20} from "solmate/test/utils/MockERC20.sol";

import {SquishiGame} from "./SquishiGame.sol";

contract VaultFactoryTest is DSTest {
    SquishiGame game;
    MockERC20 sushi;

    function setUp() public {
        sushi = new MockERC20("Sushi Token", "SUSHI", 18);
        game = new SquishiGame(sushi);
    }

    function testSanity() public {
        assertEq(game.players(), 0);
    }
}
