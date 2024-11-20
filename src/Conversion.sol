// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IConversion} from "./interfaces/IConversion.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Kwenta Acquisition Token Conversion Contract
/// @notice Responsible for converting KWENTA tokens to SNX at a fixed rate of 1:17
/// @author Jeremy Chiaramonte (jeremy@bytecode.llc)
/// @author Andrew Chiaramonte (andrewc@kwenta.io)
contract Conversion is IConversion, Ownable {
    /*//////////////////////////////////////////////////////////////
                          CONSTANTS/IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Fixed rate of 1:17 for KWENTA to SNX conversion
    uint256 public constant CONVERSION_RATE = 17;

    /// @notice Vesting cliff duration in seconds (3 months)
    uint256 public constant VESTING_CLIFF_DURATION = 90 days;

    /// @notice Linear vesting duration in seconds (9 months)
    uint256 public constant LINEAR_VESTING_DURATION = 270 days;

    /// @notice Withdrawal start time in seconds (2 years)
    uint256 public constant WITHDRAW_START = 730 days;

    /// @notice Global start time for vesting
    /// @notice Friday, November 15, 2024 12:00:00 AM (GMT)
    /// @dev From this derive 3 months cliff 9 month linear vesting
    uint256 public constant VESTING_START_TIME = 1731628800;

    // CONTRACTS //////////////////////////////////////////

    /// @notice KWENTA token contract on OE
    IERC20 private immutable KWENTA;

    /// @notice SNX token contract
    IERC20 private immutable SNX;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of addresses to the amount of SNX owed
    /// @dev the amount of SNX owed is the amount of KWENTA * CONVERSION_RATE
    mapping(address => uint256) public owedSNX;

    /// @notice Mapping of addresses to the amount of SNX claimed
    mapping(address => uint256) public claimedSNX;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _kwenta $KWENTA token address on OE
    /// @param _snx $SNX token address
    /// @param _owner Owner of the contract
    constructor(
        address _kwenta,
        address _snx,
        address _owner
    ) Ownable(_owner) {
        if (_kwenta == address(0) || _snx == address(0)) {
            revert AddressZero();
        }
        KWENTA = IERC20(_kwenta);
        SNX = IERC20(_snx);
    }

    /*///////////////////////////////////////////////////////////////
                                VIEWS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IConversion
    function vestableAmount(address _account)
        public
        view
        returns (uint256 vestableRemainder)
    {
        uint256 timeCliffEnds = VESTING_START_TIME + VESTING_CLIFF_DURATION;
        if (block.timestamp < timeCliffEnds) {
            return 0;
        }
        vestableRemainder = (
            owedSNX[_account] * (block.timestamp - timeCliffEnds)
        ) / LINEAR_VESTING_DURATION - claimedSNX[_account];
        if (vestableRemainder > owedSNX[_account]) {
            return owedSNX[_account];
        } else {
            return vestableRemainder;
        }
    }

    /*///////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IConversion
    function lockAndConvert() public {
        uint256 kwentaAmount = KWENTA.balanceOf(msg.sender);
        if (kwentaAmount == 0) {
            revert InsufficientKWENTA();
        }

        uint256 snxAmount = kwentaAmount * CONVERSION_RATE;
        owedSNX[msg.sender] += snxAmount;
        KWENTA.transferFrom(msg.sender, address(this), kwentaAmount);

        emit KWENTALocked(msg.sender, kwentaAmount);
    }

    /// @inheritdoc IConversion
    function vest() public returns (uint256) {
        return vest(msg.sender);
    }

    /// @inheritdoc IConversion
    function vest(address to) public returns (uint256 amountVested) {
        address caller = msg.sender;
        amountVested = vestableAmount(caller);
        claimedSNX[caller] += amountVested;
        SNX.transfer(to, amountVested);
        emit SNXVested(caller, to, amountVested);
    }

    /// @inheritdoc IConversion
    function withdrawSNX() public onlyOwner {
        if (block.timestamp < VESTING_START_TIME + WITHDRAW_START) {
            revert WithdrawalStartTimeNotReached();
        }
        SNX.transfer(msg.sender, SNX.balanceOf(address(this)));
    }
}
