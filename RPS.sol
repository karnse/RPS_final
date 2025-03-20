
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import './CommitReveal.sol';
import './TimeUnit.sol';

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract RPS is CommitReveal, TimeUnit {
    uint public numPlayer = 0;
    uint public numReveal = 0;
    uint public reward = 0;
    IERC20 public token;
    mapping (address => uint) public player_choice; // 0 - Rock, 1 - Paper , 2 - Scissors
    mapping(address => bool) public player_not_revaled;
    mapping(address => bool) public player_not_played;
    address[] public players;

    uint public numInput = 0;
    uint public limitTime = 2 minutes;


    constructor(address _token) {
        token = IERC20(_token);
    }

    function cleardata() private {
        numInput = 0;
        numPlayer = 0;
        numReveal = 0;
        reward = 0;
        for (uint i = 0; i < players.length; i++)
        {
            delete commits[players[i]];
            delete player_choice[players[i]];
            delete player_not_played[players[i]];
            delete player_not_revaled[players[i]];
        }
    }

    function approveForGame() public {
        require(token.approve(address(this), 0.00001 ether), "Approval failed");
    }

    function addPlayer() public {
        require(numPlayer < 2);
        if (numPlayer > 0) {
            require(msg.sender != players[0]);
        }
        player_not_played[msg.sender] = true;
        player_not_revaled[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

    function choiceHash(uint choice, bytes32 password) public pure returns(bytes32) {
        require(choice == 0 || choice == 1 || choice == 2);
        return getHash(keccak256(abi.encodePacked(choice,password)));
    }

    function input(bytes32 hashedChoice) public payable  {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);
        commit(hashedChoice);
        player_not_played[msg.sender] = false;
        numInput++;
        reward += msg.value;
        require(token.allowance(msg.sender, address(this)) >= 0.000001 ether);
    }

    function revealsChoices(uint choice, bytes32 password) public {
        require(numInput == 2);
        require(player_not_revaled[msg.sender]);
        require(choice == 0 || choice == 1 || choice == 2);
        reveal(choiceHash(choice, password));
        
        player_choice[msg.sender] = choice;
        player_not_revaled[msg.sender] = false;
        
        numReveal++;
        if (numReveal == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        if ((p0Choice + 1) % 3 == p1Choice) {
            // to pay player[1]
            token.transferFrom(players[0], players[1], reward/2);
        }
        else if ((p1Choice + 1) % 3 == p0Choice) {
            // to pay player[0]
            token.transferFrom(players[1], players[0], reward/2);
        }
        else {
            // to split reward
            token.transferFrom(players[1], players[0], reward/2);
            token.transferFrom(players[0], players[1], reward/2);
        }
    }
}
