

// 14:50:36 -----------> Code cleanup
/**
 * @notice we use more NatSpec function Documentation
 * @dev we created a pure function and view function
 * we changed calldata to memory in checkUpkeep
 */

// What Raffle.sol will be about
// ---> Enter the Lottery(paying some amount)
// ---> Pick a random winner(Verifiably random)
// ---> Winner to be selected every X minutes -> Completely automate
// ---> Chainlink Oracle -> Randomness, Automated Execution(Chainlink Keepers)

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

error Raffle__NotEnoughETHEntered();

error Raffle__transferFailed();

error Raffle__NotOpen();

error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

/**
 * @title A sample Raffle Contract
 * @author Momodu Abdulbatin Jamiu
 * @notice This contract is for creating an untamperable decentralized smart contract
 * @dev This implements Chainlink VRF v2 and Chainlink Keepers
 */

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /* Type declerations */

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State Variables */
    address payable[] private s_players;
    uint256 private immutable i_entranceFee;

    VRFCoordinatorV2Interface private immutable i_vrfcoordinator;

    bytes32 private immutable i_gasLane;

    uint64 private immutable i_subscriptionId;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint32 private immutable i_callbackGasLimit;

    uint32 private constant NUM_WORDS = 1;

    // Lottery Variables
    address private s_recentWinner;

    RaffleState private s_raffleState;

    uint256 private s_lastTimeStamp;

    uint256 private immutable i_interval;

    /* Events */
    event RaffleEnter(address indexed player);

    event RequestRaffleWinner(uint256 indexed requestId);

    event WinnerPicked(address indexed winner);

    /* Functions */

    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;

        i_vrfcoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);

        i_gasLane = gasLane;

        i_subscriptionId = subscriptionId;

        i_callbackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN;

        s_lastTimeStamp = block.timestamp;

        i_interval = interval;
    }

    function enterRaffle() public payable {
        if (msg.value > i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEnter(msg.sender);
    }

    /**
     * 
     * @dev This is the function that the Chainlink Keepers nodes call
     * they look for the `upKeepNeeded` to return true.
     * The following should be true in order to return true:
     * 1. Our time interval should have passed
     * 2. The lottery should have at least 1 player, and some ETH
     * 3. Our subscription is funded with LINK
     * 4. The lottery should be in an "open" state
     * @dev calldata dosent work well with string
     */
    function checkUpkeep(
        bytes memory /*checkData*/ // we changed it from calldata to memory bcos when we call it in performUpKeep() we want to pass it an empty string
    ) public override returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool isOpen = (RaffleState.OPEN == s_raffleState);

        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);

        bool hasPlayer = (s_players.length > 0);

        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = (isOpen && timePassed && hasPlayer && hasBalance);
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upKeepNeeded, ) = checkUpkeep("");

        if (!upKeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = i_vrfcoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];

        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);

        s_lastTimeStamp = block.timestamp;

        (bool success, ) = recentWinner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__transferFailed();
        }

        emit WinnerPicked(recentWinner);
    }

    /* View / Pure Fuctions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    // give users the chance to see the RaffleState
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    /**
     * @notice we give users the chance to see the random numbers/ random words
     * @dev we use pure instead of view bcos it is reading it from
     * the bytecode when the contract is compiled and it is not a storage variable
     * i.e for view function, it relate to storage variable
     */
    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestComfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    // At this stage here we run ---> yarn hardhat compile
    // it compiled succesfully
}
