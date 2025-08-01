// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IMasterChefV3.sol";
import "../interfaces/IMasterChefV2.sol";
import "../interfaces/IReceiver.sol";

/**
 * @dev MasterChefV3KeeperV2 was designed to use in Ethereum chain.
 * Receiver will receive fsx token, then upkeep for MasterChefV3.
 */
contract MasterChefV3KeeperV2 is KeeperCompatibleInterface, Ownable, Pausable {
    IMasterChefV3 public immutable MasterChefV3;
    IReceiver public immutable Receiver;
    IERC20 public immutable Fsx;

    address public register;

    // The next period duration for MasterChef V3.
    uint256 public PERIOD_DURATION = 1 days;

    uint256 public constant MAX_DURATION = 30 days;
    uint256 public constant MIN_DURATION = 1 days;

    // The buffer time for executing the next period in advance.
    uint256 public bufferSecond = 12 hours;
    // Avoid re-execution caused by duplicate transactions.
    uint256 public upkeepBufferSecond = 12 hours;

    error InvalidPeriodDuration();

    event NewRegister(address indexed register);
    event NewBufferSecond(uint256 bufferSecond);
    event NewUpkeepBufferSecond(uint256 upkeepBufferSecond);
    event NewPeriodDuration(uint256 periodDuration);

    /// @notice constructor.
    /// @param _V3 MasterChefV3 address.
    /// @param _receiver Receiver address.
    /// @param _fsx Fsx address.
    constructor(IMasterChefV3 _V3, IReceiver _receiver, IERC20 _fsx) {
        MasterChefV3 = _V3;
        Receiver = _receiver;
        Fsx = _fsx;
    }

    modifier onlyRegister() {
        require(msg.sender == register, "Not register");
        _;
    }

    //The logic is consistent with the following performUpkeep function, in order to make the code logic clearer.
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        if (!paused()) {
            uint256 fsxBalanceInReceiver = Fsx.balanceOf(address(Receiver));
            uint256 latestPeriodEndTime = MasterChefV3.latestPeriodEndTime();
            if (fsxBalanceInReceiver > 0 && latestPeriodEndTime < block.timestamp + bufferSecond) upkeepNeeded = true;
        }
    }

    function performUpkeep(bytes calldata) external override onlyRegister whenNotPaused {
        uint256 latestPeriodStartTime = MasterChefV3.latestPeriodStartTime();
        if (latestPeriodStartTime + upkeepBufferSecond < block.timestamp) Receiver.upkeep(0, PERIOD_DURATION, true);
    }

    /// @notice Set register.
    /// @dev Callable by owner
    /// @param _register New register.
    function setRegister(address _register) external onlyOwner {
        require(_register != address(0), "Can not be zero address");
        register = _register;
        emit NewRegister(_register);
    }

    /// @notice Set bufferSecond.
    /// @dev Callable by owner
    /// @param _bufferSecond New bufferSecond.
    function setBufferSecond(uint256 _bufferSecond) external onlyOwner {
        bufferSecond = _bufferSecond;
        emit NewBufferSecond(_bufferSecond);
    }

    /// @notice Set upkeep BufferSecond.
    /// @dev Callable by owner
    /// @param _upkeepBufferSecond New upkeep BufferSecond.
    function setUpkeepBufferSecond(uint256 _upkeepBufferSecond) external onlyOwner {
        upkeepBufferSecond = _upkeepBufferSecond;
        emit NewUpkeepBufferSecond(_upkeepBufferSecond);
    }

    /// @notice Set period duration.
    /// @dev Callable by owner
    /// @param _periodDuration New period duration.
    function setPeriodDuration(uint256 _periodDuration) external onlyOwner {
        if (_periodDuration < MIN_DURATION || _periodDuration > MAX_DURATION) revert InvalidPeriodDuration();
        PERIOD_DURATION = _periodDuration;
        emit NewPeriodDuration(_periodDuration);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
