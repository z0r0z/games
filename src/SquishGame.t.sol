// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {DSTest} from "ds-test/test.sol";

import {SquishiGame} from "./SquishiGame.sol";

contract VaultFactoryTest is DSTest {
    SquishiGame game;

    function setUp() public {
        game = new SquishiGame();
    }

    function testSanity() public {
        assertEq(game.players(), 0);
    }
}
