// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IConversion} from "./interfaces/IConversion.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Kwenta Acquisition Token Conversion Contract
/// @notice Responsible for converting KWENTA tokens to SNX at a fixed rate of 1:17
/// @author Jeremy Chiaramonte (jeremy@bytecode.llc)
/// @author Andrew Chiaramonte (andrewc@kwenta.io)
contract Conversion is IConversion {
    /*//////////////////////////////////////////////////////////////
                          CONSTANTS/IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Fixed rate of 1:17 for KWENTA to SNX conversion
    uint256 public constant CONVERSION_RATE = 17;

    /// @notice Vesting lock duration in seconds (3 months)
    uint256 public constant VESTING_LOCK_DURATION = 90 days;

    /// @notice Linear vesting duration in seconds (9 months)
    uint256 public constant LINEAR_VESTING_DURATION = 270 days;

    /// @notice Withdrawal start time in seconds (2 years)
    uint256 public constant WITHDRAW_START = 730 days;

    /// @notice Global start time for vesting
    /// @notice Friday, November 15, 2024 12:00:00 AM (GMT)
    /// @dev From this derive 3 months lock 9 month linear vesting
    uint256 public constant VESTING_START_TIME = 1_731_628_800;

    /// @notice Address of the Synthetix treasury
    address public constant SYNTHETIX_TREASURY =
        0xD25215758734dd3aDE497CE04De1c35820964126;

    /// @notice Time at which the lock ends
    /// @dev VESTING_START_TIME + VESTING_LOCK_DURATION
    /// @dev initialized during construction
    uint256 public immutable timeLockEnds;

    // CONTRACTS //////////////////////////////////////////

    /// @notice KWENTA token contract
    IERC20 public immutable KWENTA;

    /// @notice SNX token contract
    IERC20 public immutable SNX;

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

    /// @param _kwenta $KWENTA token address
    /// @param _snx $SNX token address
    constructor(address _kwenta, address _snx) {
        if (_kwenta == address(0) || _snx == address(0)) {
            revert AddressZero();
        }
        KWENTA = IERC20(_kwenta);
        SNX = IERC20(_snx);
        timeLockEnds = VESTING_START_TIME + VESTING_LOCK_DURATION;
    }

    /*///////////////////////////////////////////////////////////////
                                VIEWS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IConversion
    function vestableAmount(address _account) public view returns (uint256) {
        if (block.timestamp < timeLockEnds) {
            return 0;
        }
        uint256 vestableRemainder = (
            owedSNX[_account] * (block.timestamp - timeLockEnds)
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
    function withdrawSNX() public {
        if (msg.sender != SYNTHETIX_TREASURY) {
            revert Unauthorized();
        }
        if (block.timestamp < VESTING_START_TIME + WITHDRAW_START) {
            revert WithdrawalStartTimeNotReached();
        }
        SNX.transfer(msg.sender, SNX.balanceOf(address(this)));
    }
}
